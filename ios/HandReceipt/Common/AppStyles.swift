import SwiftUI

// MARK: - Font Definitions
public struct AppFonts {
    // Define standard sizes
    static let smallSize: CGFloat = 10
    static let captionSize: CGFloat = 12
    static let subheadlineSize: CGFloat = 14
    static let bodySize: CGFloat = 16
    static let headlineSize: CGFloat = 18
    static let titleSize: CGFloat = 22
    static let largeTitleSize: CGFloat = 28
    
    // Define letter spacing (tracking) for industrial feel
    static let tightTracking: CGFloat = -0.3
    static let normalTracking: CGFloat = 0
    static let wideTracking: CGFloat = 0.5
    static let militaryTracking: CGFloat = 1.2
    
    // Define fonts - Using more industrial/technical feel
    // Using system fonts but could be replaced with custom industrial fonts like DIN
    
    // Monospaced fonts for serial numbers and technical data
    public static let monoSmall = Font.system(.caption, design: .monospaced).monospacedDigit()
    public static let mono = Font.system(.body, design: .monospaced).monospacedDigit()
    
    // Regular text with customized tracking - apply tracking at View level with .kerning()
    public static let small = Font.system(size: smallSize, weight: .regular)
    public static let smallBold = Font.system(size: smallSize, weight: .semibold)
    
    public static let caption = Font.system(size: captionSize, weight: .regular)
    public static let captionBold = Font.system(size: captionSize, weight: .semibold)
    public static let caption2 = Font.system(size: smallSize, weight: .regular)
    
    public static let subheadline = Font.system(size: subheadlineSize, weight: .regular)
    public static let subheadlineBold = Font.system(size: subheadlineSize, weight: .semibold)
    
    public static let body = Font.system(size: bodySize, weight: .regular)
    public static let bodyBold = Font.system(size: bodySize, weight: .semibold)
    
    // Headers with wider tracking for military/industrial feel
    public static let headline = Font.system(size: headlineSize, weight: .medium)
    public static let title = Font.system(size: titleSize, weight: .medium)
    public static let largeTitle = Font.system(size: largeTitleSize, weight: .semibold)
    
    // Military style headers - all caps with wide tracking
    public static let militaryHeading = Font.system(size: headlineSize, weight: .medium)
    public static let militaryTitle = Font.system(size: titleSize, weight: .semibold)
}

// MARK: - Button Styles

// Primary button with industrial styling
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {} // Add a public initializer
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44) // Standard touch target size
            .font(AppFonts.headline)
            .foregroundColor(.white)
            .background(configuration.isPressed ? AppColors.accentHighlight : AppColors.accent)
            .cornerRadius(0) // Square corners for industrial look
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// Secondary button - outlined style
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .font(AppFonts.headline)
            .foregroundColor(AppColors.accent)
            .background(Color.clear)
            .cornerRadius(0)
            .overlay(
                Rectangle()
                    .stroke(AppColors.accent, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// Destructive button - for deletions and warnings
public struct DestructiveButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .font(AppFonts.headline)
            .foregroundColor(.white)
            .background(configuration.isPressed ? AppColors.destructive.opacity(0.8) : AppColors.destructive)
            .cornerRadius(0)
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// Extensions for easier usage
extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle {
        PrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    public static var secondary: SecondaryButtonStyle {
        SecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    public static var destructive: DestructiveButtonStyle {
        DestructiveButtonStyle()
    }
}

// MARK: - Text Field Style

public struct IndustrialTextFieldStyle: TextFieldStyle {
    public init() {} // Public initializer

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .font(AppFonts.body)
            .foregroundColor(AppColors.primaryText)
            .background(AppColors.secondaryBackground)
            .cornerRadius(0) // Square corners for industrial look
            .overlay(
                Rectangle()
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

extension TextFieldStyle where Self == IndustrialTextFieldStyle {
    public static var industrial: IndustrialTextFieldStyle {
        IndustrialTextFieldStyle()
    }
}

// MARK: - Card Style

public struct IndustrialCardModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppColors.secondaryBackground)
            .cornerRadius(0) // Square corners
            .overlay(
                Rectangle()
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

// MARK: - Section Header Style

public struct IndustrialSectionHeaderModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .font(AppFonts.militaryHeading)
            .foregroundColor(AppColors.primaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(AppColors.tertiaryBackground)
            .overlay(
                Rectangle()
                    .frame(width: 4, height: nil, alignment: .leading)
                    .foregroundColor(AppColors.accent),
                alignment: .leading
            )
    }
}

// MARK: - View Modifiers and Extensions

// MARK: - Web-Aligned Components for Dashboard

// Web-aligned card component with square corners and consistent borders
public struct WebAlignedCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(AppColors.secondaryBackground)
        .cornerRadius(0) // Match web's square corners
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

// Section header matching web styling
public struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    public init(title: String, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.title = title
        self.action = action
        self.actionLabel = actionLabel
    }
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.2)
            }
            
            Spacer()
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(label.uppercased())
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.accent)
                            .tracking(0.8)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}

// Web-aligned stat card with consistent styling
public struct WebAlignedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let onTap: (() -> Void)?
    
    public init(title: String, value: String, icon: String, color: Color, onTap: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: { onTap?() }) {
            WebAlignedCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with icon
                    HStack {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(color)
                            .frame(width: 20, height: 20)
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    
                    // Value
                    Text(value)
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.bottom, 4)
                    
                    // Title
                    Text(title.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(0.8)
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onTap == nil)
    }
}

// Web-aligned quick action card
public struct WebAlignedQuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    public init(action: QuickAction, onTap: @escaping () -> Void) {
        self.action = action
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            WebAlignedCard {
                VStack(spacing: 12) {
                    ZStack {
                        Rectangle()
                            .fill(action.color.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: action.icon)
                            .font(.title3)
                            .foregroundColor(action.color)
                    }
                    
                    Text(action.title.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.primaryText)
                        .tracking(0.8)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(PlainButtonStyle()) // Remove default button styling
    }
}

// Enhanced activity row with web styling
public struct WebAlignedActivityRow: View {
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    let iconColor: Color
    let onTap: (() -> Void)?
    
    public init(title: String, subtitle: String, time: String, icon: String, iconColor: Color, onTap: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.icon = icon
        self.iconColor = iconColor
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                Text(time)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onTap == nil)
    }
}

// Web-aligned status progress row with square corners
public struct WebAlignedStatusProgressRow: View {
    let label: String
    let value: Int
    let color: Color
    
    public init(label: String, value: Int, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Text("\(value)%")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.tertiaryBackground)
                        .frame(height: 6)
                        .cornerRadius(0) // Square corners for web alignment
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                        .cornerRadius(0) // Square corners for web alignment
                }
            }
            .frame(height: 6)
        }
    }
}

// Supporting QuickAction enum for web-aligned components
public enum QuickAction {
    case scanQR, requestTransfer, findItem, exportReport
    
    public var title: String {
        switch self {
        case .scanQR: return "Scan QR"
        case .requestTransfer: return "Request Transfer"
        case .findItem: return "Find Item"
        case .exportReport: return "Export Report"
        }
    }
    
    public var icon: String {
        switch self {
        case .scanQR: return "qrcode.viewfinder"
        case .requestTransfer: return "arrow.left.arrow.right"
        case .findItem: return "magnifyingglass"
        case .exportReport: return "doc.text"
        }
    }
    
    public var color: Color {
        switch self {
        case .scanQR: return .blue
        case .requestTransfer: return .orange
        case .findItem: return .green
        case .exportReport: return .red
        }
    }
}

public struct StandardContainerPadding: ViewModifier {
    public init() {} // Public initializer

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16) 
            .padding(.vertical, 12)
    }
}

extension View {
    // Container padding
    public func standardContainerPadding() -> some View {
        self.modifier(StandardContainerPadding())
    }
    
    // Industrial card style
    public func industrialCard() -> some View {
        self.modifier(IndustrialCardModifier())
    }
    
    // Industrial section header
    public func industrialSectionHeader() -> some View {
        self.modifier(IndustrialSectionHeaderModifier())
    }
    
    // Kerning compatibility - applies kerning on iOS 16+ or tracking on older versions
    @ViewBuilder
    public func compatibleKerning(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.kerning(value)
        } else {
            // On older iOS versions, we can't apply letter spacing
            // Just return the view unchanged
            self
        }
    }
    
    // Extension for applying tracking (letter spacing)
    // For compatibility with different iOS versions
    public func tracking(_ value: CGFloat) -> some View {
        // For backward compatibility, just return the view unchanged
        // Real tracking/kerning is handled by compatibleKerning
        return self
    }
} 