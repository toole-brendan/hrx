// ProfileView.swift - User profile information and navigation to settings
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var documentService = DocumentService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom minimal navigation bar
            MinimalNavigationBar(
                title: "PROFILE",
                titleStyle: .mono,
                showBackButton: false
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top padding
                    Color.clear.frame(height: 4)
                    
                    // Profile Information Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Profile", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            if let user = authManager.currentUser {
                                VStack(spacing: 0) {
                                    ProfileInfoRow(
                                        label: "Name",
                                        value: "\(user.rank) \(user.name)",
                                        icon: "person.fill"
                                    )
                                    
                                    Divider().background(AppColors.border)
                                    
                                    ProfileInfoRow(
                                        label: "Username",
                                        value: "@\(user.username)",
                                        icon: "at"
                                    )
                                    
                                    Divider().background(AppColors.border)
                                    
                                    ProfileInfoRow(
                                        label: "User ID",
                                        value: "#\(user.id)",
                                        icon: "number"
                                    )
                                    
                                    Divider().background(AppColors.border)
                                    
                                    ProfileInfoRow(
                                        label: "Rank",
                                        value: user.rank,
                                        icon: "star.fill"
                                    )
                                }
                            } else {
                                Text("No user information available")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding()
                            }
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Quick Actions Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Quick Actions", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: SettingsView()) {
                                ProfileActionRow(
                                    label: "Settings",
                                    icon: "gearshape",
                                    description: "App preferences and configuration"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider().background(AppColors.border)
                            
                            NavigationLink(destination: EditProfileView()) {
                                ProfileActionRow(
                                    label: "Edit Profile",
                                    icon: "person.badge.plus",
                                    description: "Update your profile information"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider().background(AppColors.border)
                            
                            NavigationLink(destination: DocumentsView()) {
                                ProfileActionRow(
                                    label: "Documents Inbox",
                                    icon: "tray.fill",
                                    description: documentService.unreadCount > 0 
                                        ? "\(documentService.unreadCount) unread documents" 
                                        : "View received documents"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Account Actions Section
                    VStack(spacing: 12) {
                        ElegantSectionHeader(title: "Account", style: .serif)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: ChangePasswordView()) {
                                ProfileActionRow(
                                    label: "Change Password",
                                    icon: "lock.rotation",
                                    description: "Update your account password"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider().background(AppColors.border)
                            
                            Button(action: {
                                Task {
                                    await authManager.logout()
                                }
                            }) {
                                ProfileActionRow(
                                    label: "Sign Out",
                                    icon: "arrow.right.square",
                                    description: "Sign out of your account",
                                    isDestructive: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .modernCard()
                        .padding(.horizontal, 24)
                    }
                    
                    // Bottom spacer
                    Color.clear.frame(height: 80)
                }
            }
            .background(AppColors.appBackground)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - Profile Row Components

struct ProfileInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(AppColors.accent)
                .frame(width: 28)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.bodyMedium)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct ProfileActionRow: View {
    let label: String
    let icon: String
    let description: String
    let isDestructive: Bool
    
    init(label: String, icon: String, description: String, isDestructive: Bool = false) {
        self.label = label
        self.icon = icon
        self.description = description
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(isDestructive ? AppColors.destructive : AppColors.accent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(isDestructive ? AppColors.destructive : AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}