// handreceipt/ios/HandReceipt/Common/IndustrialComponents.swift

import SwiftUI

// MARK: - Enhanced Status Badge with Glow Effect
public struct StatusBadge: View {
    let status: String
    let type: StatusType
    let size: BadgeSize
    
    public enum StatusType {
        case success, warning, error, info, neutral
        
        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.destructive
            case .info: return AppColors.accent
            case .neutral: return AppColors.secondaryText
            }
        }
        
        var dimColor: Color {
            switch self {
            case .success: return AppColors.successDim
            case .warning: return AppColors.warningDim
            case .error: return AppColors.destructiveDim
            case .info: return AppColors.accentDim
            case .neutral: return AppColors.tertiaryText
            }
        }
    }
    
    public enum BadgeSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return AppFonts.micro
            case .medium: return AppFonts.caption
            case .large: return AppFonts.bodySmall
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
    }
    
    public init(status: String, type: StatusType, size: BadgeSize = .medium) {
        self.status = status
        self.type = type
        self.size = size
    }
    
    public var body: some View {
        Text(status.uppercased())
            .font(size.font.weight(.bold))
            .compatibleKerning(AppFonts.wideTracking)
            .padding(size.padding)
            .foregroundColor(type.color)
            .background(type.dimColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(type.color.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(4)
            .shadow(color: type.color.opacity(0.3), radius: 4)
    }
}

// MARK: - Modern Property Card
public struct ModernPropertyCard: View {
    let property: Property
    let onTap: () -> Void
    
    public init(property: Property, onTap: @escaping () -> Void) {
        self.property = property
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(property.itemName)
                            .font(AppFonts.headlineBold)
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Text(property.serialNumber)
                            .font(AppFonts.monoSmall)
                            .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.tertiaryText)
                }
                
                // Status Row
                HStack(spacing: 12) {
                    StatusBadge(
                        status: property.currentStatus ?? "Unknown",
                        type: statusType(for: property.currentStatus),
                        size: .small
                    )
                    
                    if property.isSensitive {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10))
                            Text("SENSITIVE")
                                .font(AppFonts.microBold)
                                .compatibleKerning(AppFonts.wideTracking)
                        }
                        .foregroundColor(AppColors.warning)
                    }
                    
                    Spacer()
                    
                    if let location = property.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location)
                                .font(AppFonts.caption)
                        }
                        .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .padding(16)
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statusType(for status: String?) -> StatusBadge.StatusType {
        switch status?.lowercased() {
        case "operational": return .success
        case "maintenance", "non-operational": return .warning
        case "missing", "damaged": return .error
        default: return .neutral
        }
    }
}

// MARK: - Floating Action Button
public struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let isExpanded: Bool
    
    public init(icon: String, action: @escaping () -> Void, isExpanded: Bool = false) {
        self.icon = icon
        self.action = action
        self.isExpanded = isExpanded
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                
                if isExpanded {
                    Text("CREATE")
                        .font(AppFonts.bodyBold)
                        .compatibleKerning(AppFonts.wideTracking)
                }
            }
            .foregroundColor(Color.black)
            .padding(.horizontal, isExpanded ? 20 : 16)
            .padding(.vertical, 16)
            .background(AppColors.accent)
            .cornerRadius(isExpanded ? 28 : 56)
            .shadow(color: AppColors.accent.opacity(0.4), radius: 12, y: 4)
        }
    }
}

// MARK: - Empty State View
public struct ModernEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }
            
            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(AppFonts.headlineBold)
                    .foregroundColor(AppColors.primaryText)
                    .compatibleKerning(AppFonts.militaryTracking)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.bodyBold)
                        .compatibleKerning(AppFonts.wideTracking)
                }
                .buttonStyle(.primary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State with Industrial Spinner
public struct IndustrialLoadingView: View {
    let message: String
    
    public init(message: String = "LOADING") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(AppColors.accent)
                        .frame(width: 4, height: 20)
                        .cornerRadius(2)
                        .rotationEffect(.degrees(Double(index) * 120))
                        .offset(y: -30)
                        .rotationEffect(.degrees(Double(index) * 120))
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.2),
                            value: UUID()
                        )
                }
            }
            .frame(width: 60, height: 60)
            
            Text(message)
                .font(AppFonts.captionHeavy)
                .foregroundColor(AppColors.primaryText)
                .compatibleKerning(AppFonts.ultraWideTracking)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground.opacity(0.95))
    }
}

// MARK: - Quick Action Button Component
public struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    public init(icon: String, title: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(AppFonts.microBold)
                    .foregroundColor(AppColors.primaryText)
                    .compatibleKerning(AppFonts.wideTracking)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Category Indicator
public struct CategoryIndicator: View {
    let category: String
    let iconName: String
    
    public init(category: String, iconName: String) {
        self.category = category
        self.iconName = iconName
    }
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case _ where category.contains("weapon"):
            return AppColors.weaponsCategory
        case _ where category.contains("comm"):
            return AppColors.communicationsCategory
        case _ where category.contains("optic"):
            return AppColors.opticsCategory
        case _ where category.contains("vehicle"):
            return AppColors.vehiclesCategory
        case _ where category.contains("electronic"):
            return AppColors.electronicsCategory
        default:
            return AppColors.secondaryText
        }
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 12))
            
            Text(category.uppercased())
                .font(AppFonts.microBold)
                .compatibleKerning(AppFonts.wideTracking)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(categoryColor)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced Technical Data Display
public struct TechnicalDataField: View {
    let label: String
    let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(AppFonts.microBold)
                .foregroundColor(AppColors.tertiaryText)
                .compatibleKerning(AppFonts.militaryTracking)
            
            Text(value)
                .font(AppFonts.mono)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Modern Industrial Divider
public struct IndustrialDivider: View {
    let title: String?
    
    public init(title: String? = nil) {
        self.title = title
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            if let title = title {
                Text(title.uppercased())
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.secondaryText)
                    .compatibleKerning(AppFonts.militaryTracking)
                
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            } else {
                Rectangle()
                    .fill(AppColors.border)
                    .frame(height: 1)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Enhanced Text Editor
public struct IndustrialTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    public init(text: Binding<String>, placeholder: String) {
        self._text = text
        self.placeholder = placeholder
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.tertiaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            
            // Text Editor
            TextEditor(text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .padding(8)
                .background(AppColors.secondaryBackground)
        }
        .frame(minHeight: 100)
        .background(AppColors.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Enhanced List Item Component
public struct IndustrialListItem<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let iconName: String?
    let trailing: Trailing
    
    public init(
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.trailing = trailing()
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon if provided
            if let iconName = iconName {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24, height: 24)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppFonts.bodySmall)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
            
            // Trailing content (chevron, status, etc.)
            trailing
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.border),
            alignment: .bottom
        )
    }
}

// Convenience extension for standard list item with chevron
extension IndustrialListItem where Trailing == AnyView {
    public static func standard(
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil
    ) -> IndustrialListItem<AnyView> {
        IndustrialListItem(
            title: title,
            subtitle: subtitle,
            iconName: iconName
        ) {
            AnyView(
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryText)
            )
        }
    }
}

// MARK: - Legacy Components (preserved for compatibility)

// MARK: - Image Picker Component
public struct ImagePicker: UIViewControllerRepresentable {
    @Binding public var image: UIImage?
    public let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    public init(image: Binding<UIImage?>, sourceType: UIImagePickerController.SourceType) {
        self._image = image
        self.sourceType = sourceType
    }
    
    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        public init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Transfer Status Message Component
public struct TransferStatusMessage: View {
    let state: ScanViewModel.TransferRequestState
    
    public init(state: ScanViewModel.TransferRequestState) {
        self.state = state
    }
    
    public var body: some View {
        VStack {
            Spacer()
             if state != .idle {
                 HStack(spacing: 10) {
                     if state == .loading {
                         ProgressView()
                             .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                     } else {
                         Image(systemName: state.iconName)
                             .foregroundColor(state.iconColor)
                     }
                     Text(state.message)
                         .font(AppFonts.caption)
                         .foregroundColor(AppColors.primaryText)
                         .lineLimit(2)
                 }
                 .padding()
                 .background(state.backgroundColor)
                 .cornerRadius(8)
                 .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                 .transition(.move(edge: .bottom).combined(with: .opacity))
                 .padding(.bottom, 80)
             }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(), value: state)
    }
}

// MARK: - Transfer Request State Extensions
extension ScanViewModel.TransferRequestState {
    public var message: String {
        switch self {
            case .idle: return ""
            case .loading: return "Requesting Transfer..."
            case .success(let transferId): return "Transfer #\(transferId) Requested!"
            case .error(let msg): return "Transfer Error: \(msg)"
        }
    }

    public var iconName: String {
        switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            default: return ""
        }
    }

    public var iconColor: Color {
        switch self {
            case .success: return AppColors.accent
            case .error: return AppColors.destructive
            default: return .clear
        }
    }
    
    public var backgroundColor: Color {
         switch self {
            case .loading:
                return AppColors.secondaryBackground.opacity(0.9)
            case .success:
                return AppColors.accent.opacity(0.8)
            case .error:
                 return AppColors.destructive.opacity(0.8)
             case .idle:
                 return Color.clear
         }
     }
}

// MARK: - Enhanced Error State View
public struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }
    
    public var body: some View {
        ModernEmptyStateView(
            icon: "exclamationmark.triangle.fill",
            title: "Error Loading Data",
            message: message,
            actionTitle: "RETRY",
            action: onRetry
        )
    }
}

// MARK: - Enhanced Back Button Component
public struct EnhancedBackButton: View {
    let label: String
    let action: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    public init(label: String = "Back", action: (() -> Void)? = nil) {
        self.label = label
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            if let customAction = action {
                customAction()
            } else {
                dismiss()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(AppColors.accent)
        }
    }
}

// MARK: - Universal Header with Back Navigation
public struct UniversalHeaderView: View {
    let title: String
    let showBackButton: Bool
    let backButtonLabel: String
    let backButtonAction: (() -> Void)?
    let trailingButton: (() -> AnyView)?
    
    public init(
        title: String,
        showBackButton: Bool = true,
        backButtonLabel: String = "Back",
        backButtonAction: (() -> Void)? = nil,
        trailingButton: (() -> AnyView)? = nil
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.backButtonLabel = backButtonLabel
        self.backButtonAction = backButtonAction
        self.trailingButton = trailingButton
    }
    
    public var body: some View {
        ZStack {
            AppColors.secondaryBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    // Back button
                    if showBackButton {
                        EnhancedBackButton(label: backButtonLabel, action: backButtonAction)
                    } else {
                        // Invisible placeholder for balance
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text(backButtonLabel)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.clear)
                    }
                    
                    Spacer()
                    
                    Text(title.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(1.2)
                    
                    Spacer()
                    
                    // Trailing button or placeholder
                    if let trailingButton = trailingButton {
                        trailingButton()
                    } else {
                        // Invisible placeholder for balance
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text(backButtonLabel)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.clear)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 36)
    }
} 