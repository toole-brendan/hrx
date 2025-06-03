// SettingsView.swift - App preferences and configuration (updated with 8VC styling)
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
            VStack(spacing: 24) {
                // Spacer for header
                Color.clear
                    .frame(height: 4)
                
                // Preferences Section
                VStack(alignment: .leading, spacing: 12) {
                    ElegantSectionHeader(title: "Preferences", style: .serif)
                        .padding(.horizontal, 24)
                    
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
                    .cleanCard()
                    .padding(.horizontal, 24)
                }
                
                // Data & Storage Section
                VStack(alignment: .leading, spacing: 12) {
                    ElegantSectionHeader(title: "Data & Storage", style: .serif)
                        .padding(.horizontal, 24)
                    
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
                    .cleanCard()
                    .padding(.horizontal, 24)
                }
                
                // Application Section
                VStack(alignment: .leading, spacing: 12) {
                    ElegantSectionHeader(title: "Application", style: .serif)
                        .padding(.horizontal, 24)
                    
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
                    .cleanCard()
                    .padding(.horizontal, 24)
                }
                
                // Support Section
                VStack(alignment: .leading, spacing: 12) {
                    ElegantSectionHeader(title: "Support", style: .serif)
                        .padding(.horizontal, 24)
                    
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
                    .cleanCard()
                    .padding(.horizontal, 24)
                }
                
                // Bottom spacer
                Spacer()
                    .frame(height: 80)
            }
        }
        .background(AppColors.appBackground.ignoresSafeArea(.all))
        .minimalNavigation(
            title: "SETTINGS",
            titleStyle: .mono,
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