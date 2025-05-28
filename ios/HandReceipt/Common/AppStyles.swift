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
    
    // Extension for applying tracking (letter spacing)
    // For compatibility with different iOS versions
    public func tracking(_ value: CGFloat) -> some View {
        // No letter spacing, just return the view unchanged
        // This is backward compatible with all iOS versions
        return self
    }
} 