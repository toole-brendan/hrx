// AppColors.swift - Complete 8VC-inspired color palette
import SwiftUI

public struct AppColors {
    // MARK: - Background Colors (Light, sophisticated palette)
    public static let appBackground = Color(hex: "FAFAFA") ?? Color(.systemBackground)
    public static let secondaryBackground = Color(hex: "FFFFFF") ?? Color.white
    public static let tertiaryBackground = Color(hex: "F5F5F5") ?? Color(.systemGray6)
    public static let elevatedBackground = Color(hex: "FFFFFF") ?? Color.white
    
    // MARK: - Text Colors (High contrast black-based hierarchy)
    public static let primaryText = Color(hex: "000000") ?? Color.black
    public static let secondaryText = Color(hex: "4A4A4A") ?? Color(.label).opacity(0.7)
    public static let tertiaryText = Color(hex: "6B6B6B") ?? Color(.label).opacity(0.5)
    public static let quaternaryText = Color(hex: "9B9B9B") ?? Color(.label).opacity(0.3)
    
    // MARK: - Accent Colors (Minimal, professional)
    public static let accent = Color(hex: "0066CC") ?? Color.blue
    public static let accentHover = Color(hex: "0052A3") ?? Color.blue.opacity(0.8)
    public static let accentMuted = Color(hex: "E6F0FF") ?? Color.blue.opacity(0.1)
    
    // MARK: - Status Colors (Subtle, muted)
    public static let destructive = Color(hex: "DC3545") ?? Color.red.opacity(0.9)
    public static let warning = Color(hex: "FFC107") ?? Color.orange
    public static let success = Color(hex: "28A745") ?? Color.green.opacity(0.9)
    
    // MARK: - Border & Divider Colors
    public static let border = Color(hex: "E0E0E0") ?? Color.gray.opacity(0.2)
    public static let borderStrong = Color(hex: "CCCCCC") ?? Color.gray.opacity(0.3)
    public static let divider = Color(hex: "F0F0F0") ?? Color.gray.opacity(0.1)
    
    // MARK: - Special Purpose
    public static let shadowColor = Color.black.opacity(0.08)
    public static let overlayBackground = Color.black.opacity(0.5)
}

// AppStyles.swift - 8VC-inspired typography and components
import SwiftUI

// MARK: - Typography System
public struct AppFonts {
    // Size scale
    static let microSize: CGFloat = 11
    static let captionSize: CGFloat = 13
    static let bodySize: CGFloat = 16
    static let subheadSize: CGFloat = 18
    static let headlineSize: CGFloat = 24
    static let titleSize: CGFloat = 32
    static let heroSize: CGFloat = 48
    
    // Letter spacing
    static let tightKerning: CGFloat = -0.5
    static let normalKerning: CGFloat = 0
    static let wideKerning: CGFloat = 1.0
    static let ultraWideKerning: CGFloat = 2.0
    
    // Sans-serif fonts
    public static let body = Font.system(size: bodySize, weight: .regular)
    public static let bodyMedium = Font.system(size: bodySize, weight: .medium)
    public static let bodySemibold = Font.system(size: bodySize, weight: .semibold)
    public static let caption = Font.system(size: captionSize, weight: .regular)
    public static let captionMedium = Font.system(size: captionSize, weight: .medium)
    public static let headline = Font.system(size: headlineSize, weight: .semibold)
    public static let title = Font.system(size: titleSize, weight: .bold)
    public static let hero = Font.system(size: heroSize, weight: .bold)
    
    // Serif fonts (using system serif design)
    public static let serifHeadline = Font.system(size: headlineSize, weight: .semibold, design: .serif)
    public static let serifTitle = Font.system(size: titleSize, weight: .bold, design: .serif)
    public static let serifHero = Font.system(size: heroSize, weight: .bold, design: .serif)
    
    // Monospace fonts
    public static let monoCaption = Font.system(size: captionSize, design: .monospaced)
    public static let monoBody = Font.system(size: bodySize, design: .monospaced)
    public static let monoHeadline = Font.system(size: headlineSize, design: .monospaced).weight(.medium)
}

// MARK: - Button Styles
public struct MinimalPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
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
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyMedium)
            .foregroundColor(configuration.isPressed ? AppColors.secondaryText : AppColors.primaryText)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(configuration.isPressed ? AppColors.border : AppColors.borderStrong, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct TextLinkButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.body)
            .foregroundColor(configuration.isPressed ? AppColors.accentHover : AppColors.accent)
            .underline(configuration.isPressed)
    }
}

// MARK: - Card & Container Styles
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

// MARK: - Section Components
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
                .padding(.top, 8)
        }
        .padding(.bottom, 16)
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
                .kerning(AppFonts.ultraWideKerning)
        }
    }
}

// MARK: - Empty State
public struct MinimalEmptyState: View {
    let icon: String?
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
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

// MARK: - Stat Card Component
public struct MinimalStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let trend: Trend?
    
    public enum Trend {
        case up(String)
        case down(String)
        case neutral
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
            
            Text(value)
                .font(AppFonts.monoHeadline)
                .foregroundColor(AppColors.primaryText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            if let trend = trend {
                trendView(trend)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cleanCard(padding: 20)
    }
    
    @ViewBuilder
    private func trendView(_ trend: Trend) -> some View {
        HStack(spacing: 4) {
            switch trend {
            case .up(let value):
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .medium))
                Text(value)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.success)
            case .down(let value):
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .medium))
                Text(value)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.destructive)
            case .neutral:
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                Text("No change")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
}

// MARK: - Geometric Pattern View
public struct GeometricPatternView: View {
    public var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let size = min(width, height) * 0.8
                let offsetX = (width - size) / 2
                let offsetY = (height - size) / 2
                
                // Outer cube
                let points = [
                    CGPoint(x: offsetX + size * 0.2, y: offsetY + size * 0.3),
                    CGPoint(x: offsetX + size * 0.8, y: offsetY + size * 0.3),
                    CGPoint(x: offsetX + size * 0.8, y: offsetY + size * 0.7),
                    CGPoint(x: offsetX + size * 0.2, y: offsetY + size * 0.7)
                ]
                
                // Draw outer rectangle
                path.move(to: points[0])
                for i in 1..<4 {
                    path.addLine(to: points[i])
                }
                path.closeSubpath()
                
                // Inner nested rectangles
                for scale in stride(from: 0.8, to: 0.2, by: -0.2) {
                    let innerPoints = points.map { point in
                        let centerX = offsetX + size / 2
                        let centerY = offsetY + size / 2
                        let dx = point.x - centerX
                        let dy = point.y - centerY
                        return CGPoint(
                            x: centerX + dx * scale,
                            y: centerY + dy * scale
                        )
                    }
                    
                    path.move(to: innerPoints[0])
                    for i in 1..<4 {
                        path.addLine(to: innerPoints[i])
                    }
                    path.closeSubpath()
                }
            }
            .stroke(AppColors.border, lineWidth: 1)
        }
    }
}

// MARK: - View Extensions
extension View {
    public func cleanCard(padding: CGFloat = 24, showShadow: Bool = true) -> some View {
        self.modifier(CleanCardModifier(padding: padding, showShadow: showShadow))
    }
    
    public func kerning(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            return self.tracking(value)
        } else {
            return self
        }
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