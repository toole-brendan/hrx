// SettingsRowViews.swift - Reusable row components for settings screens
import SwiftUI

// MARK: - Settings Row Components

struct SettingsRow: View {
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
                    .foregroundColor(AppColors.accent)
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
                .foregroundColor(AppColors.accent)
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
                    .foregroundColor(AppColors.accent)
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
                .foregroundColor(AppColors.accent)
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
            
            VStack(spacing: 20) {
                Text("SYNCING")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                    .compatibleKerning(AppFonts.wideKerning)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(AppFonts.monoBody)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(30)
            .cleanCard()
            .frame(width: 280)
        }
    }
} 