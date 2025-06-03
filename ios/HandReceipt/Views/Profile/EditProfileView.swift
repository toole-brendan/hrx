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
        VStack(spacing: 0) {
            // Custom minimal navigation bar
            MinimalNavigationBar(
                title: "EDIT PROFILE",
                titleStyle: .mono,
                showBackButton: true,
                backAction: { dismiss() }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top padding
                    Color.clear.frame(height: 4)
                    
                    // Personal Information Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Personal Information", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            ModernFormField(
                                label: "First Name",
                                text: $firstName,
                                icon: "person.fill"
                            )
                            
                            Divider().background(AppColors.border)
                            
                            ModernFormField(
                                label: "Last Name",
                                text: $lastName,
                                icon: "person.fill"
                            )
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Contact Information Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Contact Information", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            ModernFormField(
                                label: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Military Information Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Military Information", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            ModernFormField(
                                label: "Rank",
                                text: $rank,
                                icon: "star.fill"
                            )
                            
                            Divider().background(AppColors.border)
                            
                            ModernFormField(
                                label: "Unit/Organization",
                                text: $unit,
                                icon: "building.2.fill"
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
                    
                    // Save Button
                    Button(action: saveProfile) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Saving...")
                                    .font(AppFonts.bodyMedium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.accent.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text("Save Changes")
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
                    // Update the auth manager with the new user data
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
                .font(.system(size: 18, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                TextField("", text: $text)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocapitalization(.none)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationView {
        EditProfileView()
            .environmentObject(AuthManager.shared)
    }
} 