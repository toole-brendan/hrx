import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var notificationsEnabled = true
    @State private var biometricsEnabled = false
    @State private var autoSyncEnabled = true
    @State private var showingClearCacheAlert = false
    @State private var showingSyncStatus = false
    @State private var syncProgress: Double = 0
    @State private var isSyncing = false
    
    // Services
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Account Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Account")
                        
                        WebAlignedCard {
                            if let user = authManager.currentUser {
                                VStack(spacing: 0) {
                                    SettingsRow(
                                        label: "Name",
                                        value: "\(user.rank) \(user.name)",
                                        icon: "person.fill"
                                    )
                                    
                                    Divider().background(AppColors.border)
                                    
                                    SettingsRow(
                                        label: "Username",
                                        value: "@\(user.username)",
                                        icon: "at"
                                    )
                                    
                                    Divider().background(AppColors.border)
                                    
                                    SettingsRow(
                                        label: "User ID",
                                        value: "#\(user.id)",
                                        icon: "number"
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Preferences")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    label: "Push Notifications",
                                    icon: "bell.fill",
                                    isOn: $notificationsEnabled,
                                    description: "Receive alerts for transfers and maintenance"
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsToggleRow(
                                    label: "Biometric Authentication",
                                    icon: "faceid",
                                    isOn: $biometricsEnabled,
                                    description: "Use Face ID or Touch ID to unlock"
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsToggleRow(
                                    label: "Auto-Sync",
                                    icon: "arrow.triangle.2.circlepath",
                                    isOn: $autoSyncEnabled,
                                    description: "Automatically sync when online"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Data & Storage Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Data & Storage")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                SettingsActionRow(
                                    label: "Force Sync",
                                    icon: "arrow.triangle.2.circlepath",
                                    iconColor: AppColors.accent,
                                    action: performSync,
                                    showProgress: isSyncing,
                                    progress: syncProgress
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsActionRow(
                                    label: "Clear Cache",
                                    icon: "trash",
                                    iconColor: .orange,
                                    action: { showingClearCacheAlert = true }
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsInfoRow(
                                    label: "Storage Used",
                                    icon: "internaldrive",
                                    value: calculateStorageUsed()
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Application Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Application")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    label: "Version",
                                    icon: "info.circle",
                                    value: getAppVersion()
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsInfoRow(
                                    label: "Build",
                                    icon: "hammer",
                                    value: getBuildNumber()
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsStatusRow(
                                    label: "Server Status",
                                    icon: "server.rack",
                                    status: .connected
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsInfoRow(
                                    label: "Last Sync",
                                    icon: "clock",
                                    value: getLastSyncTime()
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Support Section
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(title: "Support")
                        
                        WebAlignedCard {
                            VStack(spacing: 0) {
                                SettingsNavigationRow(
                                    label: "Help & Documentation",
                                    icon: "questionmark.circle",
                                    destination: AnyView(HelpView())
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsNavigationRow(
                                    label: "Report an Issue",
                                    icon: "exclamationmark.bubble",
                                    destination: AnyView(ReportIssueView())
                                )
                                
                                Divider().background(AppColors.border)
                                
                                SettingsNavigationRow(
                                    label: "About HandReceipt",
                                    icon: "info.circle",
                                    destination: AnyView(AboutView())
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sign Out Button
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authManager.logout()
                        }
                    }
                    .buttonStyle(.destructive)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            SettingsHeaderSection()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will remove all cached data. You may need to re-sync your data.")
        }
        .overlay(
            Group {
                if showingSyncStatus {
                    SyncStatusOverlay(progress: syncProgress)
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func performSync() {
        withAnimation {
            isSyncing = true
            showingSyncStatus = true
            syncProgress = 0
        }
        
        // Simulate sync progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if syncProgress < 1.0 {
                syncProgress += 0.05
            } else {
                timer.invalidate()
                withAnimation {
                    isSyncing = false
                    showingSyncStatus = false
                    syncProgress = 0
                }
            }
        }
    }
    
    private func clearCache() {
        // TODO: Implement actual cache clearing
        print("Clearing cache...")
    }
    
    private func calculateStorageUsed() -> String {
        // TODO: Calculate actual storage
        return "42.3 MB"
    }
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func getLastSyncTime() -> String {
        // TODO: Get actual last sync time
        return "2 minutes ago"
    }
}

// MARK: - Settings Header Section
struct SettingsHeaderSection: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
    }
}

// MARK: - Settings Row Components

struct SettingsRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 24)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
        }
        .padding()
    }
}

struct SettingsToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    let description: String?
    
    init(label: String, icon: String, isOn: Binding<Bool>, description: String? = nil) {
        self.label = label
        self.icon = icon
        self._isOn = isOn
        self.description = description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    if let description = description {
                        Text(description)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }
        }
        .padding()
    }
}

struct SettingsActionRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    let showProgress: Bool
    let progress: Double
    
    init(label: String, icon: String, iconColor: Color, action: @escaping () -> Void, showProgress: Bool = false, progress: Double = 0) {
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if showProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsInfoRow: View {
    let label: String
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 24)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
        }
        .padding()
    }
}

struct SettingsNavigationRow: View {
    let label: String
    let icon: String
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsStatusRow: View {
    enum Status {
        case connected, disconnected, connecting
        
        var color: Color {
            switch self {
            case .connected: return AppColors.success
            case .disconnected: return AppColors.destructive
            case .connecting: return AppColors.warning
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            }
        }
    }
    
    let label: String
    let icon: String
    let status: Status
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 24)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                
                Text(status.text)
                    .font(AppFonts.body)
                    .foregroundColor(status.color)
            }
        }
        .padding()
    }
}

// MARK: - Sync Status Overlay
struct SyncStatusOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            WebAlignedCard {
                VStack(spacing: 20) {
                    Text("SYNCING")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                        .frame(width: 200)
                    
                    Text("\(Int(progress * 100))%")
                        .font(AppFonts.mono)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(30)
            }
            .frame(width: 280)
        }
    }
}

// MARK: - Placeholder Views

struct HelpView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 36)
                    
                    Text("Help & Documentation")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    WebAlignedCard {
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.secondaryText)
                            
                            Text("Help Coming Soon")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Comprehensive help documentation will be available here.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("HELP")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: 36)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

struct ReportIssueView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 36)
                    
                    Text("Report an Issue")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    WebAlignedCard {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.secondaryText)
                            
                            Text("Issue Reporting Coming Soon")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("You'll be able to report bugs and request features here.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("REPORT ISSUE")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: 36)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

struct AboutView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 36)
                    
                    Text("About HandReceipt")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    WebAlignedCard {
                        VStack(spacing: 16) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.accent)
                            
                            Text("HandReceipt")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("Digital military property management system for efficient equipment tracking and accountability.")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            
            // Header
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("ABOUT")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .kerning(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: 36)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
        .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
    }
} 