// ProfileView.swift - User profile information and navigation to settings
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Profile Information Section
                    VStack(alignment: .leading, spacing: 0) {
                        ElegantSectionHeader(title: "Profile", style: .uppercase)
                        
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
                        .cleanCard()
                        .padding(.horizontal)
                    }
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 0) {
                        ElegantSectionHeader(title: "Quick Actions", style: .uppercase)
                        
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
                            
                            Button(action: {
                                // TODO: Implement edit profile functionality
                            }) {
                                ProfileActionRow(
                                    label: "Edit Profile",
                                    icon: "person.badge.plus",
                                    description: "Update your profile information"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider().background(AppColors.border)
                            
                            Button(action: {
                                // TODO: Implement view activity functionality
                            }) {
                                ProfileActionRow(
                                    label: "Activity History",
                                    icon: "clock.arrow.circlepath",
                                    description: "View your recent activity"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .cleanCard()
                        .padding(.horizontal)
                    }
                    
                    // Account Actions Section
                    VStack(alignment: .leading, spacing: 0) {
                        ElegantSectionHeader(title: "Account", style: .uppercase)
                        
                        VStack(spacing: 0) {
                            Button(action: {
                                // TODO: Implement change password functionality
                            }) {
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
                        .cleanCard()
                        .padding(.horizontal)
                    }
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            .minimalNavigation(
                title: "Profile",
                titleStyle: .minimal,
                showBackButton: false,
                trailingItems: [
                    MinimalNavigationBar.NavItem(icon: "gearshape", style: .icon) {
                        showingSettings = true
                    }
                ]
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Profile Row Components

struct ProfileInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.bodyMedium)
                .foregroundColor(AppColors.primaryText)
        }
        .padding()
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isDestructive ? AppColors.destructive : AppColors.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(isDestructive ? AppColors.destructive : AppColors.primaryText)
                
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
} 