import SwiftUI

// MARK: - Enhanced Font System
public struct AppFonts {
    // Size definitions with better hierarchy
    static let microSize: CGFloat = 10      // New: For badges and labels
    static let smallSize: CGFloat = 12      // Captions
    static let bodySmallSize: CGFloat = 14  // Secondary body text
    static let bodySize: CGFloat = 16       // Primary body
    static let subheadSize: CGFloat = 18    // Subheadings
    static let headlineSize: CGFloat = 20   // Headlines
    static let titleSize: CGFloat = 24      // Titles
    static let largeTitleSize: CGFloat = 32 // Large titles
    static let heroSize: CGFloat = 40       // New: Hero text
    
    // Tracking for industrial feel
    static let tightTracking: CGFloat = -0.5
    static let normalTracking: CGFloat = 0
    static let wideTracking: CGFloat = 0.8
    static let ultraWideTracking: CGFloat = 1.5
    static let militaryTracking: CGFloat = 2.0
    
    // Font definitions with improved hierarchy
    public static let micro = Font.system(size: microSize, weight: .medium)
    public static let microBold = Font.system(size: microSize, weight: .bold)
    
    public static let caption = Font.system(size: smallSize, weight: .regular)
    public static let captionBold = Font.system(size: smallSize, weight: .semibold)
    public static let captionHeavy = Font.system(size: smallSize, weight: .heavy)
    
    public static let bodySmall = Font.system(size: bodySmallSize, weight: .regular)
    public static let bodySmallBold = Font.system(size: bodySmallSize, weight: .semibold)
    
    public static let body = Font.system(size: bodySize, weight: .regular)
    public static let bodyBold = Font.system(size: bodySize, weight: .semibold)
    public static let bodyHeavy = Font.system(size: bodySize, weight: .bold)
    
    public static let subhead = Font.system(size: subheadSize, weight: .regular)
    public static let subheadBold = Font.system(size: subheadSize, weight: .semibold)
    
    public static let headline = Font.system(size: headlineSize, weight: .semibold)
    public static let headlineBold = Font.system(size: headlineSize, weight: .bold)
    
    public static let title = Font.system(size: titleSize, weight: .bold)
    public static let titleHeavy = Font.system(size: titleSize, weight: .heavy)
    
    public static let largeTitle = Font.system(size: largeTitleSize, weight: .bold)
    public static let largeTitleHeavy = Font.system(size: largeTitleSize, weight: .heavy)
    
    public static let hero = Font.system(size: heroSize, weight: .heavy)
    
    // Technical/Monospace fonts
    public static let monoMicro = Font.system(size: microSize, design: .monospaced)
    public static let monoSmall = Font.system(size: smallSize, design: .monospaced)
    public static let mono = Font.system(size: bodySize, design: .monospaced)
    public static let monoLarge = Font.system(size: subheadSize, design: .monospaced)
    
    // Legacy compatibility
    public static let small = micro
    public static let smallBold = microBold
    public static let caption2 = micro
    public static let subheadline = bodySmall
    public static let subheadlineBold = bodySmallBold
    public static let militaryHeading = headline
    public static let militaryTitle = title
}

// MARK: - Industrial Back Button Style
public struct IndustrialBackButton: View {
    let action: () -> Void
    let label: String
    
    public init(label: String = "Back", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(AppFonts.bodyBold)
            }
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.accent.opacity(0.1))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Enhanced Button Styles with Better Contrast
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .font(AppFonts.bodyBold)
            .foregroundColor(Color.black)
            .background(
                Group {
                    if !isEnabled {
                        AppColors.accent.opacity(0.3)
                    } else if configuration.isPressed {
                        AppColors.accentHighlight
                    } else {
                        AppColors.accent
                    }
                }
            )
            .cornerRadius(4)
            .shadow(color: AppColors.accent.opacity(isEnabled ? 0.3 : 0), radius: 8, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Secondary button - outlined style with modern styling
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .font(AppFonts.bodyBold)
            .foregroundColor(AppColors.accent)
            .background(Color.clear)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.accent, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Destructive button with enhanced styling
public struct DestructiveButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .font(AppFonts.bodyBold)
            .foregroundColor(.white)
            .background(configuration.isPressed ? AppColors.destructive.opacity(0.8) : AppColors.destructive)
            .cornerRadius(4)
            .shadow(color: AppColors.destructive.opacity(0.3), radius: 8, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Card Style with Depth
public struct ModernCardModifier: ViewModifier {
    let isElevated: Bool
    
    public init(isElevated: Bool = false) {
        self.isElevated = isElevated
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(isElevated ? AppColors.elevatedBackground : AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: isElevated ? 12 : 4, y: isElevated ? 6 : 2)
    }
}

// MARK: - Section Header with Better Typography
public struct ModernSectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionLabel: String?
    
    public init(title: String, subtitle: String? = nil, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionLabel = actionLabel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(AppFonts.captionHeavy)
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(AppFonts.militaryTracking)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                if let action = action, let label = actionLabel {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            Text(label.uppercased())
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.accent)
                                .compatibleKerning(AppFonts.wideTracking)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            
            // Section divider line
            Rectangle()
                .fill(AppColors.accent.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}

// MARK: - Enhanced Navigation Bar Style
public struct IndustrialNavigationModifier: ViewModifier {
    let title: String
    let showBackButton: Bool
    let backButtonAction: (() -> Void)?
    let trailingItems: [NavigationBarItem]
    
    public struct NavigationBarItem {
        let icon: String
        let action: () -> Void
        let isDestructive: Bool
        
        public init(icon: String, action: @escaping () -> Void, isDestructive: Bool = false) {
            self.icon = icon
            self.action = action
            self.isDestructive = isDestructive
        }
    }
    
    public init(
        title: String,
        showBackButton: Bool = true,
        backButtonAction: (() -> Void)? = nil,
        trailingItems: [NavigationBarItem] = []
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.backButtonAction = backButtonAction
        self.trailingItems = trailingItems
    }
    
    public func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(showBackButton && backButtonAction != nil)
            .toolbar(content: {
                ToolbarItem(placement: .principal) {
                    Text(title.uppercased())
                        .font(AppFonts.headlineBold)
                        .foregroundColor(AppColors.primaryText)
                        .compatibleKerning(AppFonts.wideTracking)
                }
                
                if showBackButton, let action = backButtonAction {
                    ToolbarItem(placement: .navigationBarLeading) {
                        IndustrialBackButton(action: action)
                    }
                }
                
                if !trailingItems.isEmpty {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        ForEach(trailingItems.indices, id: \.self) { index in
                            Button(action: trailingItems[index].action) {
                                Image(systemName: trailingItems[index].icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(
                                        trailingItems[index].isDestructive ? 
                                        AppColors.destructive : AppColors.accent
                                    )
                            }
                        }
                    }
                }
            })
    }
}

// MARK: - Enhanced Text Field Style
public struct IndustrialTextFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .font(AppFonts.body)
            .foregroundColor(AppColors.primaryText)
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

// MARK: - Legacy Card Style (for compatibility)
public struct IndustrialCardModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

// MARK: - Section Header Style (legacy)
public struct IndustrialSectionHeaderModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .font(AppFonts.headlineBold)
            .foregroundColor(AppColors.primaryText)
            .textCase(.uppercase)
            .compatibleKerning(AppFonts.militaryTracking)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
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

// MARK: - Button Style Extensions
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

extension TextFieldStyle where Self == IndustrialTextFieldStyle {
    public static var industrial: IndustrialTextFieldStyle {
        IndustrialTextFieldStyle()
    }
}

// MARK: - View Extensions
extension View {
    public func modernCard(isElevated: Bool = false) -> some View {
        self.modifier(ModernCardModifier(isElevated: isElevated))
    }
    
    public func industrialNavigation(
        title: String,
        showBackButton: Bool = true,
        backButtonAction: (() -> Void)? = nil,
        trailingItems: [IndustrialNavigationModifier.NavigationBarItem] = []
    ) -> some View {
        self.modifier(
            IndustrialNavigationModifier(
                title: title,
                showBackButton: showBackButton,
                backButtonAction: backButtonAction,
                trailingItems: trailingItems
            )
        )
    }
    
    // Legacy compatibility
    public func industrialCard() -> some View {
        self.modifier(IndustrialCardModifier())
    }
    
    public func industrialSectionHeader() -> some View {
        self.modifier(IndustrialSectionHeaderModifier())
    }
    
    public func standardContainerPadding() -> some View {
        self.padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
    
    // Kerning compatibility - applies kerning on iOS 16+ or returns unchanged on older versions
    @ViewBuilder
    public func compatibleKerning(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.kerning(value)
        } else {
            // On older iOS versions, just return the view unchanged
            self
        }
    }
}

// MARK: - Legacy Web-Aligned Components (preserved for compatibility)
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
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

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
        ModernSectionHeader(title: title, action: action, actionLabel: actionLabel)
    }
}

// Supporting QuickAction enum for web-aligned components
public enum QuickAction {
    case requestTransfer, findItem
    
    public var title: String {
        switch self {
        case .requestTransfer: return "Request Transfer"
        case .findItem: return "Find Item"
        }
    }
    
    public var icon: String {
        switch self {
        case .requestTransfer: return "arrow.left.arrow.right"
        case .findItem: return "magnifyingglass"
        }
    }
    
    public var color: Color {
        switch self {
        case .requestTransfer: return AppColors.warning
        case .findItem: return AppColors.success
        }
    }
} 