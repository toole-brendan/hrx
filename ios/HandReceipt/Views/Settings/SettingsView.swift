// SettingsView.swift - App preferences and configuration (8VC styled)
import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
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
        ScrollView {
            VStack(spacing: 32) {
                // Minimal top padding
                Color.clear.frame(height: 8)
                
                // Preferences Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "PREFERENCES")
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            label: "Push Notifications",
                            icon: "bell",
                            isOn: $notificationsEnabled,
                            description: "Receive alerts for transfers and maintenance"
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsToggleRow(
                            label: "Biometric Authentication",
                            icon: "faceid",
                            isOn: $biometricsEnabled,
                            description: "Use Face ID or Touch ID to unlock"
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsToggleRow(
                            label: "Auto-Sync",
                            icon: "arrow.triangle.2.circlepath",
                            isOn: $autoSyncEnabled,
                            description: "Automatically sync when online"
                        )
                    }
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(4)
                    .shadow(color: AppColors.shadowColor, radius: 2, y: 1)
                    .padding(.horizontal, 24)
                }
                
                // Data & Storage Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "DATA & STORAGE")
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        SettingsActionRow(
                            label: "Force Sync",
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: AppColors.accent,
                            action: performSync,
                            showProgress: isSyncing
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsActionRow(
                            label: "Clear Cache",
                            icon: "trash",
                            iconColor: AppColors.warning,
                            action: { showingClearCacheAlert = true }
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsInfoRow(
                            label: "Storage Used",
                            icon: "internaldrive",
                            value: calculateStorageUsed()
                        )
                    }
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(4)
                    .shadow(color: AppColors.shadowColor, radius: 2, y: 1)
                    .padding(.horizontal, 24)
                }
                
                // Application Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "APPLICATION")
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        SettingsInfoRow(
                            label: "Version",
                            icon: "info.circle",
                            value: getAppVersion()
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsInfoRow(
                            label: "Build",
                            icon: "hammer",
                            value: getBuildNumber()
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsStatusRow(
                            label: "Server Status",
                            icon: "server.rack",
                            status: .connected
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsInfoRow(
                            label: "Last Sync",
                            icon: "clock",
                            value: getLastSyncTime()
                        )
                    }
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(4)
                    .shadow(color: AppColors.shadowColor, radius: 2, y: 1)
                    .padding(.horizontal, 24)
                }
                
                // Support Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "SUPPORT")
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 0) {
                        SettingsNavigationRow(
                            label: "Help & Documentation",
                            icon: "questionmark.circle",
                            destination: AnyView(HelpView())
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsNavigationRow(
                            label: "Report an Issue",
                            icon: "exclamationmark.bubble",
                            destination: AnyView(ReportIssueView())
                        )
                        
                        Divider().background(AppColors.divider)
                        
                        SettingsNavigationRow(
                            label: "About HandReceipt",
                            icon: "info.circle",
                            destination: AnyView(AboutView())
                        )
                    }
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(4)
                    .shadow(color: AppColors.shadowColor, radius: 2, y: 1)
                    .padding(.horizontal, 24)
                }
                
                // Bottom spacer - reduced from 80
                Spacer().frame(height: 40)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea())
        .minimalNavigation(
            title: "SETTINGS",
            titleStyle: .mono,  // Official style for settings screens
            showBackButton: true,
            backAction: { dismiss() }
        )
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

// MARK: - Section Label Component
struct SectionLabel: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(AppFonts.captionMedium)
            .foregroundColor(AppColors.secondaryText)
            .kerning(AppFonts.ultraWideKerning)
            .padding(.bottom, 4)
    }
} 