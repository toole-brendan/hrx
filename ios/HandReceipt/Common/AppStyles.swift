// handreceipt/ios/HandReceipt/Common/AppStyles.swift

import SwiftUI

// MARK: - 8VC-Inspired Typography System
public struct AppFonts {
    // Size scale (refined for elegance)
    static let microSize: CGFloat = 11
    static let captionSize: CGFloat = 13
    static let bodySize: CGFloat = 16
    static let subheadSize: CGFloat = 18
    static let headlineSize: CGFloat = 24
    static let titleSize: CGFloat = 32
    static let heroSize: CGFloat = 48
    
    // Letter spacing (reduced from military style)
    static let tightKerning: CGFloat = -0.5
    static let normalKerning: CGFloat = 0
    static let wideKerning: CGFloat = 1.0
    static let ultraWideKerning: CGFloat = 2.0
    
    // MARK: - Sans-serif fonts (Primary)
    public static let body = Font.system(size: bodySize, weight: .regular)
    public static let bodyMedium = Font.system(size: bodySize, weight: .medium)
    public static let bodySemibold = Font.system(size: bodySize, weight: .semibold)
    public static let caption = Font.system(size: captionSize, weight: .regular)
    public static let captionMedium = Font.system(size: captionSize, weight: .medium)
    public static let headline = Font.system(size: headlineSize, weight: .semibold)
    public static let title = Font.system(size: titleSize, weight: .bold)
    public static let hero = Font.system(size: heroSize, weight: .bold)
    
    // MARK: - Serif fonts (For elegant headers)
    public static let serifHeadline = Font.system(size: headlineSize, weight: .semibold, design: .serif)
    public static let serifTitle = Font.system(size: titleSize, weight: .bold, design: .serif)
    public static let serifHero = Font.system(size: heroSize, weight: .bold, design: .serif)
    
    // MARK: - Monospace fonts (For technical content)
    public static let monoCaption = Font.system(size: captionSize, design: .monospaced)
    public static let monoBody = Font.system(size: bodySize, design: .monospaced)
    public static let monoHeadline = Font.system(size: headlineSize, design: .monospaced).weight(.medium)
    
    // MARK: - Special styles
    public static let uppercaseLabel = Font.system(size: captionSize, weight: .semibold)
    public static let metadata = Font.system(size: captionSize, weight: .regular)
    
    // MARK: - Legacy compatibility (mapped to new system)
    public static let micro = Font.system(size: microSize, weight: .medium)
    public static let microBold = Font.system(size: microSize, weight: .bold)
    public static let captionBold = captionMedium
    public static let captionHeavy = Font.system(size: captionSize, weight: .semibold)
    public static let bodySmall = body
    public static let bodySmallBold = bodyMedium
    public static let bodyBold = bodyMedium
    public static let bodyHeavy = bodySemibold
    public static let subhead = Font.system(size: subheadSize, weight: .regular)
    public static let subheadBold = Font.system(size: subheadSize, weight: .semibold)
    public static let headlineBold = headline
    public static let titleHeavy = title
    public static let largeTitle = title
    public static let largeTitleHeavy = title
    public static let monoMicro = Font.system(size: microSize, design: .monospaced)
    public static let monoSmall = monoCaption
    public static let mono = monoBody
    public static let monoLarge = monoHeadline
    public static let small = micro
    public static let smallBold = microBold
    public static let caption2 = micro
    public static let subheadline = bodySmall
    public static let subheadlineBold = bodySmallBold
    public static let militaryHeading = headline
    public static let militaryTitle = title
    
    // Legacy tracking values (kept for compatibility)
    static let tightTracking: CGFloat = tightKerning
    static let normalTracking: CGFloat = normalKerning
    static let wideTracking: CGFloat = wideKerning
    static let ultraWideTracking: CGFloat = ultraWideKerning
    static let militaryTracking: CGFloat = ultraWideKerning
}

// MARK: - Minimal Button Styles
public struct MinimalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Group {
                    if !isEnabled {
                        AppColors.primaryText.opacity(0.3)
                    } else if configuration.isPressed {
                        AppColors.primaryText.opacity(0.8)
                    } else {
                        AppColors.primaryText
                    }
                }
            )
            .cornerRadius(4)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct MinimalSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyMedium)
            .foregroundColor(configuration.isPressed ? AppColors.secondaryText : AppColors.primaryText)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        configuration.isPressed ? AppColors.border : AppColors.borderStrong,
                        lineWidth: 1
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct TextLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 1) {
            configuration.label
                .font(AppFonts.body)
                .foregroundColor(configuration.isPressed ? AppColors.accentHover : AppColors.accent)
                .opacity(isEnabled ? 1.0 : 0.5)
            
            // Custom underline for backwards compatibility
            if configuration.isPressed {
                Rectangle()
                    .fill(configuration.isPressed ? AppColors.accentHover : AppColors.accent)
                    .frame(height: 1)
                    .opacity(isEnabled ? 1.0 : 0.5)
            }
        }
    }
}

// Legacy button styles (updated to use minimal design)
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        MinimalPrimaryButtonStyle().makeBody(configuration: configuration)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        MinimalSecondaryButtonStyle().makeBody(configuration: configuration)
    }
}

public struct DestructiveButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? AppColors.destructive.opacity(0.8) : AppColors.destructive)
            .cornerRadius(4)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Clean Card Styles
public struct CleanCardModifier: ViewModifier {
    let padding: CGFloat
    let showShadow: Bool
    
    public init(padding: CGFloat = 24, showShadow: Bool = true) {
        self.padding = padding
        self.showShadow = showShadow
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .shadow(
                color: showShadow ? AppColors.shadowColor : Color.clear,
                radius: showShadow ? 4 : 0,
                x: 0,
                y: showShadow ? 2 : 0
            )
    }
}

// MARK: - Elegant Section Headers
public struct ElegantSectionHeader: View {
    let title: String
    let subtitle: String?
    let style: HeaderStyle
    let action: (() -> Void)?
    let actionLabel: String?
    
    public enum HeaderStyle {
        case serif
        case sans
        case mono
        case uppercase
    }
    
    public init(
        title: String,
        subtitle: String? = nil,
        style: HeaderStyle = .sans,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.action = action
        self.actionLabel = actionLabel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    titleView
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                if let action = action, let label = actionLabel {
                    Button(action: action) {
                        Text(label)
                            .font(AppFonts.captionMedium)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            
            Divider()
                .background(AppColors.divider)
                .padding(.top, 4)
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var titleView: some View {
        switch style {
        case .serif:
            Text(title)
                .font(AppFonts.serifHeadline)
                .foregroundColor(AppColors.primaryText)
        case .sans:
            Text(title)
                .font(AppFonts.headline)
                .foregroundColor(AppColors.primaryText)
        case .mono:
            Text(title)
                .font(AppFonts.monoHeadline)
                .foregroundColor(AppColors.primaryText)
        case .uppercase:
            Text(title.uppercased())
                .font(AppFonts.captionMedium)
                .foregroundColor(AppColors.secondaryText)
                .compatibleKerning(AppFonts.ultraWideKerning)
        }
    }
}

// MARK: - Minimal Empty State
public struct MinimalEmptyState: View {
    let icon: String?
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    public init(
        icon: String? = nil,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }
    
    public var body: some View {
        VStack(spacing: 32) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                }
                .buttonStyle(MinimalPrimaryButtonStyle())
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Minimal Back Button
public struct MinimalBackButton: View {
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
                    .font(.system(size: 14, weight: .regular))
                Text(label)
                    .font(AppFonts.body)
            }
            .foregroundColor(AppColors.secondaryText)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy Compatibility Components (Updated Styles)
public struct IndustrialBackButton: View {
    let action: () -> Void
    let label: String
    
    public init(label: String = "Back", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
    
    public var body: some View {
        MinimalBackButton(label: label, action: action)
    }
}

public struct ModernCardModifier: ViewModifier {
    let isElevated: Bool
    
    public init(isElevated: Bool = false) {
        self.isElevated = isElevated
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(20)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .shadow(
                color: AppColors.shadowColor,
                radius: isElevated ? 8 : 4,
                x: 0,
                y: isElevated ? 4 : 2
            )
    }
}

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
        ElegantSectionHeader(
            title: title,
            subtitle: subtitle,
            style: .uppercase,
            action: action,
            actionLabel: actionLabel
        )
    }
}

// MARK: - Minimal Text Field Style
public struct MinimalTextFieldStyle: TextFieldStyle {
    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .font(AppFonts.body)
            .foregroundColor(AppColors.primaryText)
            .background(AppColors.secondaryBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.border, lineWidth: 1)
            )
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
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}

// MARK: - Legacy Card Style (Updated)
public struct IndustrialCardModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .modifier(CleanCardModifier(padding: 20))
    }
}

// MARK: - Section Header Style (Legacy)
public struct IndustrialSectionHeaderModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .font(AppFonts.headline)
            .foregroundColor(AppColors.primaryText)
            .textCase(.uppercase)
            .compatibleKerning(AppFonts.wideKerning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
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
        let modifiedContent = content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(showBackButton && backButtonAction != nil)
            .navigationBarItems(
                leading: showBackButton && backButtonAction != nil ? IndustrialBackButton(action: backButtonAction!) : nil,
                trailing: !trailingItems.isEmpty ? HStack(spacing: 16) {
                    ForEach(trailingItems.indices, id: \.self) { index in
                        Button(action: trailingItems[index].action) {
                            Image(systemName: trailingItems[index].icon)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(
                                    trailingItems[index].isDestructive ? 
                                    AppColors.destructive : AppColors.accent
                                )
                        }
                    }
                } : nil
            )
        
        return modifiedContent
            .navigationTitle(title)
    }
}

// MARK: - Button Style Extensions
extension ButtonStyle where Self == MinimalPrimaryButtonStyle {
    public static var minimalPrimary: MinimalPrimaryButtonStyle {
        MinimalPrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == MinimalSecondaryButtonStyle {
    public static var minimalSecondary: MinimalSecondaryButtonStyle {
        MinimalSecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    public static var textLink: TextLinkButtonStyle {
        TextLinkButtonStyle()
    }
}

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

extension TextFieldStyle where Self == MinimalTextFieldStyle {
    public static var minimal: MinimalTextFieldStyle {
        MinimalTextFieldStyle()
    }
}

extension TextFieldStyle where Self == IndustrialTextFieldStyle {
    public static var industrial: IndustrialTextFieldStyle {
        IndustrialTextFieldStyle()
    }
}

// MARK: - Section Divider Modifier
public struct SectionDividerModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
            content
        }
    }
}

// MARK: - View Extensions
extension View {
    public func cleanCard(padding: CGFloat = 24, showShadow: Bool = true) -> some View {
        self.modifier(CleanCardModifier(padding: padding, showShadow: showShadow))
    }
    
    public func sectionDivider() -> some View {
        self.modifier(SectionDividerModifier())
    }
    
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
    
    public func industrialCard() -> some View {
        self.modifier(IndustrialCardModifier())
    }
    
    public func industrialSectionHeader() -> some View {
        self.modifier(IndustrialSectionHeaderModifier())
    }
    
    public func standardContainerPadding() -> some View {
        self.padding(.horizontal, 24)
            .padding(.vertical, 16)
    }
    
    @ViewBuilder
    public func compatibleKerning(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.kerning(value)
        } else {
            self
        }
    }
}

// MARK: - Legacy Web-Aligned Components (Updated)
public struct WebAlignedCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .cleanCard()
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
        ElegantSectionHeader(title: title, action: action, actionLabel: actionLabel)
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