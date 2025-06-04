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
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal navigation bar
                MinimalNavigationBar(
                    title: "CHANGE PASSWORD",
                    titleStyle: .mono,
                    showBackButton: true,
                    backAction: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Security Notice
                        securityNotice
                        
                        // Current Password Section
                        currentPasswordSection
                        
                        // New Password Section
                        newPasswordSection
                        
                        // Password Requirements
                        passwordRequirementsSection
                        
                        // Error Message
                        if let error = errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(AppFonts.caption)
                            }
                            .foregroundColor(AppColors.destructive)
                            .padding(.horizontal, 20)
                        }
                        
                        // Update Password Button
                        updatePasswordButton
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
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
    
    // MARK: - Sections
    
    private var securityNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.accent)
            
            Text("Verify your identity before setting a new password")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentMuted)
        .cornerRadius(4)
        .padding(.horizontal, 20)
    }
    
    private var currentPasswordSection: some View {
        VStack(spacing: 12) {
            MinimalSectionHeader(title: "CURRENT PASSWORD")
                .padding(.horizontal, 20)
            
            MinimalSecureField(
                placeholder: "Enter current password",
                text: $currentPassword,
                icon: "lock"
            )
            .padding(.horizontal, 20)
        }
    }
    
    private var newPasswordSection: some View {
        VStack(spacing: 12) {
            MinimalSectionHeader(title: "NEW PASSWORD")
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                MinimalSecureField(
                    placeholder: "Enter new password",
                    text: $newPassword,
                    icon: "lock.rotation"
                )
                
                MinimalSecureField(
                    placeholder: "Confirm new password",
                    text: $confirmNewPassword,
                    icon: "lock.rotation"
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var passwordRequirementsSection: some View {
        VStack(spacing: 12) {
            MinimalSectionHeader(title: "REQUIREMENTS")
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                MinimalRequirementRow(
                    requirement: "At least 8 characters",
                    isMet: newPassword.count >= 8
                )
                
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 1)
                    .padding(.leading, 44)
                
                MinimalRequirementRow(
                    requirement: "Passwords match",
                    isMet: passwordsMatch && !newPassword.isEmpty
                )
            }
            .cleanCard(padding: 0)
            .padding(.horizontal, 20)
        }
    }
    
    private var updatePasswordButton: some View {
        Button(action: changePassword) {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Updating...")
                        .font(AppFonts.bodyMedium)
                }
            } else {
                Text("Update Password")
                    .font(AppFonts.bodyMedium)
            }
        }
        .buttonStyle(.minimalPrimary)
        .disabled(!formIsValid || isLoading)
    }
    
    // MARK: - Actions
    
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

// MARK: - Supporting Components

struct MinimalSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(12)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(4)
    }
}

struct MinimalRequirementRow: View {
    let requirement: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(isMet ? AppColors.success : AppColors.tertiaryText)
                .frame(width: 20)
            
            Text(requirement)
                .font(AppFonts.caption)
                .foregroundColor(isMet ? AppColors.primaryText : AppColors.secondaryText)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}



#Preview {
    NavigationView {
        ChangePasswordView()
            .environmentObject(AuthManager.shared)
    }
} 