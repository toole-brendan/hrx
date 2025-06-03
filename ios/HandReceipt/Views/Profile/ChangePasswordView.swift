// ChangePasswordView.swift - Password change interface
import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false
    @State private var isLoading = false
    
    var passwordsMatch: Bool {
        newPassword == confirmNewPassword && !newPassword.isEmpty
    }
    
    var newPasswordStrong: Bool {
        newPassword.count >= 8
    }
    
    var formIsValid: Bool {
        !currentPassword.isEmpty && passwordsMatch && newPasswordStrong
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom minimal navigation bar
            MinimalNavigationBar(
                title: "CHANGE PASSWORD",
                titleStyle: .mono,
                showBackButton: true,
                backAction: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top padding
                    Color.clear.frame(height: 4)
                    
                    // Security Notice
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Security Notice", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.accent)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Secure Password Change")
                                        .font(AppFonts.bodyMedium)
                                        .foregroundColor(AppColors.primaryText)
                                    
                                    Text("Enter your current password to verify your identity before setting a new password.")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                }
                                
                                Spacer()
                            }
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Current Password Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Current Password", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            SecureFormField(
                                label: "Current Password",
                                text: $currentPassword,
                                icon: "lock.fill"
                            )
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // New Password Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "New Password", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            SecureFormField(
                                label: "New Password",
                                text: $newPassword,
                                icon: "lock.rotation"
                            )
                            
                            Divider().background(AppColors.border)
                            
                            SecureFormField(
                                label: "Confirm New Password",
                                text: $confirmNewPassword,
                                icon: "lock.rotation"
                            )
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Password Requirements
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Password Requirements", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 12) {
                            PasswordRequirementRow(
                                requirement: "At least 8 characters",
                                isMet: newPassword.count >= 8
                            )
                            
                            PasswordRequirementRow(
                                requirement: "Passwords match",
                                isMet: passwordsMatch && !newPassword.isEmpty
                            )
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.destructive)
                            .padding(.horizontal, 24)
                    }
                    
                    // Update Password Button
                    Button(action: changePassword) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Updating...")
                                    .font(AppFonts.bodyMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.accent.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("Update Password")
                                .font(AppFonts.bodyMedium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(formIsValid ? AppColors.accent : AppColors.border)
                                .foregroundColor(formIsValid ? .white : AppColors.tertiaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .disabled(!formIsValid || isLoading)
                    .padding(.horizontal, 24)
                    
                    // Bottom spacer
                    Color.clear.frame(height: 80)
                }
            }
            .background(AppColors.appBackground)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Password Changed"),
                message: Text("Your password has been updated successfully."),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }
    
    private func changePassword() {
        guard formIsValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let userId = authManager.currentUser?.id else {
                    throw APIService.APIError.unauthorized
                }
                
                try await APIService.shared.changePassword(
                    userId: userId,
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                
                await MainActor.run {
                    isLoading = false
                    currentPassword = ""
                    newPassword = ""
                    confirmNewPassword = ""
                    showSuccessAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let apiError = error as? APIService.APIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = "Failed to update password. Please try again."
                    }
                }
            }
        }
    }
}

// MARK: - Secure Form Field Component

struct SecureFormField: View {
    let label: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                SecureField("", text: $text)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Password Requirement Row

struct PasswordRequirementRow: View {
    let requirement: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isMet ? AppColors.accent : AppColors.tertiaryText)
            
            Text(requirement)
                .font(AppFonts.caption)
                .foregroundColor(isMet ? AppColors.primaryText : AppColors.secondaryText)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        ChangePasswordView()
            .environmentObject(AuthManager.shared)
    }
} 