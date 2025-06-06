// NavigationComponents.swift - 8VC-inspired navigation bars and toolbars
import SwiftUI

// MARK: - Primary Navigation Bar (Main screens)
public struct MinimalNavigationBar: View {
    let title: String
    let titleStyle: TitleStyle
    let showBackButton: Bool
    let backAction: (() -> Void)?
    let trailingItems: [NavItem]
    
    public enum TitleStyle {
        case hidden          // No title shown
        case serif           // Elegant serif font
        case mono            // Monospace (technical screens)
        case minimal         // Small, understated
        case hero            // Large, prominent
    }
    
    public struct NavItem {
        let icon: String?
        let text: String?
        let action: () -> Void
        let style: ItemStyle
        
        public enum ItemStyle {
            case icon
            case text
            case iconWithText
        }
        
        public init(icon: String? = nil, text: String? = nil, style: ItemStyle = .icon, action: @escaping () -> Void) {
            self.icon = icon
            self.text = text
            self.style = style
            self.action = action
        }
    }
    
    public init(
        title: String = "",
        titleStyle: TitleStyle = .minimal,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        trailingItems: [NavItem] = []
    ) {
        self.title = title
        self.titleStyle = titleStyle
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.trailingItems = trailingItems
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // Leading area
                HStack {
                    if showBackButton, let action = backAction {
                        MinimalBackButton(action: action)
                    } else {
                        // App logo or brand mark
                        Text("HR")
                            .font(AppFonts.monoBody)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
                .frame(minWidth: 60, alignment: .leading)
                
                Spacer()
                
                // Center title
                if titleStyle != .hidden {
                    titleView
                }
                
                Spacer()
                
                // Trailing items
                HStack(spacing: 20) {
                    ForEach(trailingItems.indices, id: \.self) { index in
                        NavItemButton(item: trailingItems[index])
                    }
                }
                .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                AppColors.secondaryBackground
                    .ignoresSafeArea(.container, edges: .top)
            )
            
            // Subtle divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
        .background(AppColors.secondaryBackground)
    }
    
    @ViewBuilder
    private var titleView: some View {
        switch titleStyle {
        case .hidden:
            EmptyView()
        case .serif:
            Text(title)
                .font(AppFonts.serifHeadline)
                .foregroundColor(AppColors.primaryText)
        case .mono:
            Text(title.uppercased())
                .font(AppFonts.monoCaption)
                .foregroundColor(AppColors.primaryText)
                .compatibleKerning(AppFonts.wideKerning)
        case .minimal:
            Text(title)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
        case .hero:
            Text(title)
                .font(AppFonts.title)
                .foregroundColor(AppColors.primaryText)
        }
    }
}

// MARK: - Navigation Item Button
struct NavItemButton: View {
    let item: MinimalNavigationBar.NavItem
    
    var body: some View {
        Button(action: item.action) {
            switch item.style {
            case .icon:
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(AppColors.primaryText)
                }
            case .text:
                if let text = item.text {
                    Text(text)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
            case .iconWithText:
                HStack(spacing: 6) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .light))
                    }
                    if let text = item.text {
                        Text(text)
                            .font(AppFonts.body)
                    }
                }
                .foregroundColor(AppColors.primaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MinimalTabBar has been moved to Views/Navigation/MinimalTabBar.swift

// MARK: - Inline Page Header (For sections within a screen)
public struct InlinePageHeader: View {
    let title: String
    let subtitle: String?
    let style: HeaderStyle
    
    public enum HeaderStyle {
        case large      // Big serif title
        case standard   // Normal heading
        case minimal    // Small, understated
    }
    
    public init(title: String, subtitle: String? = nil, style: HeaderStyle = .standard) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch style {
            case .large:
                Text(title)
                    .font(AppFonts.serifTitle)
                    .foregroundColor(AppColors.primaryText)
            case .standard:
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
            case .minimal:
                Text(title.uppercased())
                    .font(AppFonts.captionMedium)
                    .foregroundColor(AppColors.secondaryText)
                    .compatibleKerning(AppFonts.ultraWideKerning)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - Contextual Toolbar (For actions within a view)
public struct MinimalToolbar: View {
    let items: [ToolbarItem]
    
    public struct ToolbarItem {
        let icon: String
        let label: String
        let action: () -> Void
        let isDestructive: Bool
        
        public init(icon: String, label: String, action: @escaping () -> Void, isDestructive: Bool = false) {
            self.icon = icon
            self.label = label
            self.action = action
            self.isDestructive = isDestructive
        }
    }
    
    public init(items: [ToolbarItem]) {
        self.items = items
    }
    
    public var body: some View {
        HStack(spacing: 32) {
            ForEach(items.indices, id: \.self) { index in
                ToolbarButton(item: items[index])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1),
            alignment: .top
        )
    }
    
    struct ToolbarButton: View {
        let item: ToolbarItem
        
        var body: some View {
            Button(action: item.action) {
                VStack(spacing: 6) {
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .light))
                    Text(item.label.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .compatibleKerning(AppFonts.wideKerning)
                }
                .foregroundColor(item.isDestructive ? AppColors.destructive : AppColors.primaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - View Extension for Easy Integration
extension View {
    public func minimalNavigation(
        title: String = "",
        titleStyle: MinimalNavigationBar.TitleStyle = .minimal,
        showBackButton: Bool = true,
        backAction: (() -> Void)? = nil,
        trailingItems: [MinimalNavigationBar.NavItem] = []
    ) -> some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: title,
                titleStyle: titleStyle,
                showBackButton: showBackButton,
                backAction: backAction,
                trailingItems: trailingItems
            )
            self
        }
        .navigationBarHidden(true)
    }
    
    public func minimalToolbar(items: [MinimalToolbar.ToolbarItem]) -> some View {
        VStack(spacing: 0) {
            self
            MinimalToolbar(items: items)
        }
    }
} 