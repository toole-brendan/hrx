// SettingsRowViews.swift - Reusable row components for settings screens (8VC styled)
import SwiftUI

// MARK: - Settings Row Components

struct SettingsRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.monoBody)  // Monospace for values
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, description != nil ? 10 : 12)
    }
}

struct SettingsActionRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    let showProgress: Bool
    
    init(label: String, icon: String, iconColor: Color, action: @escaping () -> Void, showProgress: Bool = false) {
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.showProgress = showProgress
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if showProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(AppColors.quaternaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.monoCaption)  // Monospace for technical values
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 20)
                
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(AppColors.quaternaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                .font(.system(size: 16, weight: .light))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                
                Text(status.text)
                    .font(AppFonts.monoCaption)  // Monospace for status
                    .foregroundColor(status.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Sync Status Overlay
struct SyncStatusOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("SYNCING")
                    .font(AppFonts.captionMedium)
                    .foregroundColor(AppColors.primaryText)
                    .kerning(AppFonts.ultraWideKerning)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                    .frame(width: 180)
                
                Text("\(Int(progress * 100))%")
                    .font(AppFonts.monoBody)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(24)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .shadow(color: AppColors.shadowColor, radius: 8, y: 4)
            .frame(width: 240)
        }
    }
} 