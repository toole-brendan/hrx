import SwiftUI

// MARK: - Industrial UI Components

// Status badge with military-inspired styling
public struct StatusBadge: View {
    let status: String
    let type: StatusType
    
    public enum StatusType {
        case success
        case warning
        case error
        case info
        case neutral
        
        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.destructive
            case .info: return AppColors.accent
            case .neutral: return AppColors.secondaryText
            }
        }
    }
    
    public init(status: String, type: StatusType) {
        self.status = status
        self.type = type
    }
    
    public var body: some View {
        Text(status.uppercased())
            .font(AppFonts.smallBold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(type.color.opacity(0.15))
            .foregroundColor(type.color)
            .overlay(
                Rectangle()
                    .stroke(type.color.opacity(0.5), lineWidth: 1)
            )
    }
}

// Category indicator for military equipment types
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
                .font(AppFonts.smallBold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(categoryColor)
        .background(categoryColor.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// Technical Data Display for serial numbers, NSNs, etc.
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
                .font(AppFonts.small)
                .foregroundColor(AppColors.tertiaryText)
            
            Text(value)
                .font(AppFonts.mono)
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.vertical, 4)
    }
}

// Industrial Section Divider
public struct IndustrialDivider: View {
    let title: String?
    
    public init(title: String? = nil) {
        self.title = title
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            if let title = title {
                Text(title.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 1)
            } else {
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(height: 1)
            }
        }
        .padding(.vertical, 12)
    }
}

// Industrial TextEditor
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
            
            // Text Editor
            TextEditor(text: $text)
                .font(AppFonts.body)
                .foregroundColor(AppColors.primaryText)
                .padding(4) // Adjust internal TextEditor padding
                .background(AppColors.secondaryBackground)
        }
        .frame(minHeight: 100)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

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
            Spacer() // Push to bottom
             if state != .idle { // Only show if not idle
                 HStack(spacing: 10) {
                     if state == .loading {
                         ProgressView()
                             .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                     } else {
                         Image(systemName: state.iconName)
                             .foregroundColor(state.iconColor) // Use themed color from extension
                     }
                     Text(state.message)
                         .font(AppFonts.caption) // Use theme font
                         .foregroundColor(AppColors.primaryText)
                         .lineLimit(2)
                 }
                 .padding()
                 .background(state.backgroundColor) // Use themed background from extension
                 .cornerRadius(10)
                 .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                 .transition(.move(edge: .bottom).combined(with: .opacity))
                 .padding(.bottom, 80) // Position above ScanStatusOverlay
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
            case .success(let transfer): return "Transfer #\(transfer.id) Requested!"
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
            case .success: return AppColors.accent // Use theme accent for success
            case .error: return AppColors.destructive
            default: return .clear
        }
    }
    
    public var backgroundColor: Color {
         switch self {
            case .loading:
                return AppColors.secondaryBackground.opacity(0.9)
            case .success:
                return AppColors.accent.opacity(0.8) // Use theme accent background
            case .error:
                 return AppColors.destructive.opacity(0.8)
             case .idle:
                 return Color.clear
         }
     }
}

// Error State View Component
public struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.destructive)
            
            VStack(spacing: 8) {
                Text("Error Loading Data")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Retry", action: onRetry)
                .buttonStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Industrial ListItem component
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
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppFonts.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
            
            // Trailing content (chevron, status, etc.)
            trailing
        }
        .padding(.vertical, 12)
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