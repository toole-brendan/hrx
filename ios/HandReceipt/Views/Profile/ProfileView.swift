// ProfileView.swift - User profile information and navigation to settings
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var documentService = DocumentService.shared
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal navigation bar
                MinimalNavigationBar(
                    title: "PROFILE",
                    titleStyle: .mono,
                    showBackButton: false
                )
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Information Section
                        profileInfoSection
                        
                        // Quick Actions Section
                        quickActionsSection
                        
                        // Support Section
                        supportSection
                        
                        // Account Actions Section
                        accountActionsSection
                        
                        // Bottom padding
                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Functions
    
    private func formatUserName(user: LoginResponse.User) -> String {
        if let lastName = user.lastName, let firstName = user.firstName,
           !lastName.isEmpty, !firstName.isEmpty {
            return "\(lastName), \(firstName)"
        } else if let lastName = user.lastName, !lastName.isEmpty {
            return lastName
        } else if let firstName = user.firstName, !firstName.isEmpty {
            return firstName
        } else {
            return "No name available"
        }
    }
    
    // MARK: - Sections
    
    private var profileInfoSection: some View {
        VStack(spacing: 16) {
            ProfileSectionHeader(title: "USER INFORMATION")
                .padding(.horizontal, 20)
            
            if let user = authManager.currentUser {
                VStack(spacing: 0) {
                    ProfileInfoRow(
                        label: "NAME",
                        value: formatUserName(user: user),
                        icon: "person",
                        valueFont: .mono
                    )
                    
                    ProfileDivider()
                    
                    ProfileInfoRow(
                        label: "EMAIL",
                        value: user.email ?? "No email",
                        icon: "envelope",
                        valueFont: .mono
                    )
                    
                    ProfileDivider()
                    
                    ProfileInfoRow(
                        label: "RANK",
                        value: user.rank,
                        icon: "star",
                        valueFont: .mono
                    )
                }
                .cleanCard(padding: 0)
                .padding(.horizontal, 20)
            } else {
                ProfileEmptyState(
                    icon: "person.crop.circle",
                    title: "No User Data",
                    message: "User information unavailable"
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            ProfileSectionHeader(title: "QUICK ACTIONS")
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                NavigationLink(destination: SettingsView()) {
                    ProfileActionRow(
                        label: "Settings",
                        icon: "gearshape",
                        description: "App preferences"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ProfileDivider()
                
                NavigationLink(destination: EditProfileView()) {
                    ProfileActionRow(
                        label: "Edit Profile",
                        icon: "square.and.pencil",
                        description: "Update your information"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ProfileDivider()
                
                NavigationLink(destination: DocumentsView()) {
                    ProfileActionRow(
                        label: "Documents",
                        icon: "tray",
                        description: documentService.unreadCount > 0 
                            ? "\(documentService.unreadCount) unread" 
                            : "View inbox",
                        badge: documentService.unreadCount > 0 ? "\(documentService.unreadCount)" : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .cleanCard(padding: 0)
            .padding(.horizontal, 20)
        }
    }
    
    private var supportSection: some View {
        VStack(spacing: 16) {
            ProfileSectionHeader(title: "SUPPORT")
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                NavigationLink(destination: AboutView()) {
                    ProfileActionRow(
                        label: "About",
                        icon: "info.circle",
                        description: "Learn more about the app"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ProfileDivider()
                
                NavigationLink(destination: HelpView()) {
                    ProfileActionRow(
                        label: "Help",
                        icon: "questionmark.circle",
                        description: "Get assistance"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ProfileDivider()
                
                NavigationLink(destination: ReportIssueView()) {
                    ProfileActionRow(
                        label: "Report Issue",
                        icon: "exclamationmark.triangle",
                        description: "Report a problem"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .cleanCard(padding: 0)
            .padding(.horizontal, 20)
        }
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: 16) {
            ProfileSectionHeader(title: "ACCOUNT")
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                NavigationLink(destination: ChangePasswordView()) {
                    ProfileActionRow(
                        label: "Change Password",
                        icon: "lock.rotation",
                        description: "Update security"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                ProfileDivider()
                
                Button(action: {
                    Task {
                        await authManager.logout()
                    }
                }) {
                    ProfileActionRow(
                        label: "Sign Out",
                        icon: "arrow.right.square",
                        description: "End session",
                        isDestructive: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .cleanCard(padding: 0)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Profile-specific Supporting Components

struct ProfileSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(AppFonts.ultraWideKerning)
            
            Spacer()
        }
    }
}

struct ProfileInfoRow: View {
    let label: String
    let value: String
    let icon: String
    var valueFont: FontType = .sans
    
    enum FontType {
        case sans, mono
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .frame(width: 70, alignment: .leading)
            
            switch valueFont {
            case .sans:
                Text(value)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            case .mono:
                Text(value)
                    .font(AppFonts.monoBody)
                    .foregroundColor(AppColors.primaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct ProfileActionRow: View {
    let label: String
    let icon: String
    let description: String
    let isDestructive: Bool
    let badge: String?
    
    init(label: String, icon: String, description: String, isDestructive: Bool = false, badge: String? = nil) {
        self.label = label
        self.icon = icon
        self.description = description
        self.isDestructive = isDestructive
        self.badge = badge
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(isDestructive ? AppColors.destructive : AppColors.secondaryText)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(isDestructive ? AppColors.destructive : AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(AppFonts.monoCaption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.accent)
                    .cornerRadius(10)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct ProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 1)
            .padding(.leading, 52)
    }
}

struct ProfileEmptyState: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(AppColors.tertiaryText)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .cleanCard()
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}