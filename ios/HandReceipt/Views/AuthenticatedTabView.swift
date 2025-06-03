// AuthenticatedTabView.swift - Updated with MinimalTabBar
import SwiftUI

struct AuthenticatedTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authManager: AuthManager
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content using custom implementation instead of TabView
            tabContent
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            
            // Custom minimal tab bar
            MinimalTabBar(
                selectedTab: $selectedTab,
                items: [
                    .init(icon: "house", label: "Home", tag: 0),
                    .init(icon: "shippingbox", label: "Property", tag: 1),
                    .init(icon: "arrow.left.arrow.right", label: "Transfers", tag: 2),
                    .init(icon: "person", label: "Profile", tag: 3)
                ]
            )
        }
        .background(AppColors.appBackground)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        NavigationView {
            switch selectedTab {
            case 0:
                DashboardView(
                    apiService: apiService,
                    onTabSwitch: { tab in
                        withAnimation {
                            selectedTab = tab
                        }
                    }
                )
                .transition(.opacity)
                
            case 1:
                MyPropertiesView(apiService: apiService)
                    .transition(.opacity)
                
            case 2:
                TransfersView(apiService: apiService)
                    .transition(.opacity)
                
            case 3:
                SettingsView()
                    .transition(.opacity)
                
            default:
                DashboardView(
                    apiService: apiService,
                    onTabSwitch: { tab in
                        withAnimation {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Updated Settings View with minimal styling
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            MinimalNavigationBar(
                title: "Settings",
                titleStyle: .minimal,
                showBackButton: false
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // User profile section
                    userProfileSection
                    
                    // Settings sections
                    VStack(spacing: 24) {
                        settingsSection(title: "Account", items: accountItems)
                        settingsSection(title: "Preferences", items: preferenceItems)
                        settingsSection(title: "About", items: aboutItems)
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign out button
                    signOutButton
                        .padding(.horizontal, 24)
                        .padding(.vertical, 40)
                }
            }
            .background(AppColors.appBackground)
        }
        .navigationBarHidden(true)
    }
    
    private var userProfileSection: some View {
        VStack(spacing: 16) {
            // Profile picture placeholder
            Circle()
                .fill(AppColors.tertiaryBackground)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AppColors.secondaryText)
                )
            
            // User info
            VStack(spacing: 4) {
                Text(authManager.currentUser?.name ?? "User")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(authManager.currentUser?.email ?? "")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
        .sectionDivider()
    }
    
    private func settingsSection(title: String, items: [SettingsItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ElegantSectionHeader(
                title: title,
                style: .uppercase
            )
            
            VStack(spacing: 0) {
                ForEach(items) { item in
                    settingsRow(item: item)
                    
                    if item.id != items.last?.id {
                        Divider()
                            .background(AppColors.divider)
                            .padding(.leading, 20)
                    }
                }
            }
            .cleanCard(padding: 0, showShadow: false)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
    
    private func settingsRow(item: SettingsItem) -> some View {
        Button(action: item.action) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                Text(item.title)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if let value = item.value {
                    Text(value)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var signOutButton: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.minimalSecondary)
    }
    
    // Settings data
    private var accountItems: [SettingsItem] {
        [
            SettingsItem(icon: "person.circle", title: "Profile", action: {}),
            SettingsItem(icon: "bell", title: "Notifications", action: {}),
            SettingsItem(icon: "shield", title: "Security", action: {}),
        ]
    }
    
    private var preferenceItems: [SettingsItem] {
        [
            SettingsItem(icon: "moon", title: "Dark Mode", value: "Off", action: {}),
            SettingsItem(icon: "textformat", title: "Text Size", value: "Default", action: {}),
            SettingsItem(icon: "arrow.down.circle", title: "Auto-sync", value: "On", action: {}),
        ]
    }
    
    private var aboutItems: [SettingsItem] {
        [
            SettingsItem(icon: "info.circle", title: "Version", value: "1.0.0", action: {}),
            SettingsItem(icon: "doc.text", title: "Terms of Service", action: {}),
            SettingsItem(icon: "hand.raised", title: "Privacy Policy", action: {}),
        ]
    }
    
    private func signOut() {
        authManager.logout()
    }
}

// Settings item model
struct SettingsItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    var value: String? = nil
    let action: () -> Void
}