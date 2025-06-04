// EditProfileView.swift - User profile editing interface
import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var rank: String = ""
    @State private var unit: String = ""
    
    @State private var showSaveConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var formIsValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && 
        !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "Edit Profile",
                    titleStyle: .mono,
                    showBackButton: true,
                    backAction: { dismiss() }
                )
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Personal Information
                        VStack(alignment: .leading, spacing: 16) {
                            ElegantSectionHeader(
                                title: "Personal Information",
                                style: .uppercase
                            )
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ModernFormField(
                                    label: "First Name",
                                    text: $firstName,
                                    icon: "person"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                ModernFormField(
                                    label: "Last Name",
                                    text: $lastName,
                                    icon: "person"
                                )
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 20)
                        }
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 16) {
                            ElegantSectionHeader(
                                title: "Contact Information",
                                style: .uppercase
                            )
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ModernFormField(
                                    label: "Email Address",
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    textContentType: .emailAddress
                                )
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 20)
                        }
                        
                        // Military Information
                        VStack(alignment: .leading, spacing: 16) {
                            ElegantSectionHeader(
                                title: "Military Information",
                                style: .uppercase
                            )
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ModernFormField(
                                    label: "Rank",
                                    text: $rank,
                                    icon: "star"
                                )
                                
                                Divider()
                                    .background(AppColors.divider)
                                
                                ModernFormField(
                                    label: "Unit/Organization",
                                    text: $unit,
                                    icon: "building.2"
                                )
                            }
                            .cleanCard(padding: 0)
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.destructive)
                                .padding(.horizontal, 20)
                        }
                        
                        // Save Button
                        Button(action: saveProfile) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Saving...")
                                        .font(AppFonts.bodyMedium)
                                } else {
                                    Text("Save Changes")
                                        .font(AppFonts.bodyMedium)
                                }
                            }
                        }
                        .buttonStyle(MinimalPrimaryButtonStyle())
                        .disabled(!formIsValid || isLoading)
                        .padding(.horizontal, 20)
                        
                        // Bottom safe area
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadCurrentUserData()
        }
        .alert(isPresented: $showSaveConfirmation) {
            Alert(
                title: Text("Profile Updated"),
                message: Text("Your profile information has been saved successfully."),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }
    
    private func loadCurrentUserData() {
        guard let user = authManager.currentUser else { return }
        
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        email = user.email ?? ""
        rank = user.rank
        unit = user.unit ?? ""
    }
    
    private func saveProfile() {
        guard formIsValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        let profileData: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "rank": rank,
            "unit": unit
        ]
        
        Task {
            do {
                guard let userId = authManager.currentUser?.id else {
                    throw APIService.APIError.unauthorized
                }
                
                let updatedUser = try await APIService.shared.updateUserProfile(
                    userId: userId,
                    profileData: profileData
                )
                
                await MainActor.run {
                    authManager.currentUser = updatedUser
                    isLoading = false
                    showSaveConfirmation = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let apiError = error as? APIService.APIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = "Failed to update profile. Please try again."
                    }
                }
            }
        }
    }
}

// MARK: - Modern Form Field Component

struct ModernFormField: View {
    let label: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .kerning(AppFonts.wideKerning)
                
                TextField("", text: $text)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocapitalization(.none)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationView {
        EditProfileView()
            .environmentObject(AuthManager.shared)
    }
} 