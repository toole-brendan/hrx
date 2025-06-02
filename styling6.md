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
                            .foregroundColor(AppColors.secondaryText)
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
            .padding(.vertical, 16)
            .background(AppColors.appBackground)
            
            // Subtle divider
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
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
                .foregroundColor(AppColors.secondaryText)
                .kerning(AppFonts.wideKerning)
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

// MARK: - Tab Bar Alternative (Bottom Navigation)
public struct MinimalTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    
    public struct TabItem {
        let icon: String
        let label: String
        let tag: Int
        
        public init(icon: String, label: String, tag: Int) {
            self.icon = icon
            self.label = label
            self.tag = tag
        }
    }
    
    public init(selectedTab: Binding<Int>, items: [TabItem]) {
        self._selectedTab = selectedTab
        self.items = items
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach(items, id: \.tag) { item in
                    TabButton(
                        item: item,
                        isSelected: selectedTab == item.tag,
                        action: { selectedTab = item.tag }
                    )
                }
            }
            .padding(.vertical, 8)
            .background(AppColors.appBackground)
        }
    }
    
    struct TabButton: View {
        let item: TabItem
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: isSelected ? .regular : .light))
                        .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                    
                    Text(item.label.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                        .kerning(AppFonts.wideKerning)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

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
                    .kerning(AppFonts.ultraWideKerning)
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
                        .kerning(AppFonts.wideKerning)
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

// MARK: - Usage Examples
struct NavigationExamplesView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Example 1: Main navigation with serif title
            MinimalNavigationBar(
                title: "Property Details",
                titleStyle: .serif,
                showBackButton: true,
                backAction: { /* go back */ },
                trailingItems: [
                    .init(icon: "square.and.arrow.up", action: { /* share */ }),
                    .init(icon: "ellipsis", action: { /* more */ })
                ]
            )
            
            ScrollView {
                VStack(spacing: 40) {
                    // Example 2: Inline page header
                    InlinePageHeader(
                        title: "Transfer History",
                        subtitle: "All property transfers in the system",
                        style: .large
                    )
                    
                    // Content...
                    Color.clear.frame(height: 400)
                }
            }
            
            // Example 3: Minimal toolbar
            MinimalToolbar(items: [
                .init(icon: "arrow.left.arrow.right", label: "Transfer", action: {}),
                .init(icon: "qrcode", label: "Scan", action: {}),
                .init(icon: "trash", label: "Delete", action: {}, isDestructive: true)
            ])
            
            // Example 4: Tab bar
            MinimalTabBar(
                selectedTab: $selectedTab,
                items: [
                    .init(icon: "house", label: "Home", tag: 0),
                    .init(icon: "shippingbox", label: "Property", tag: 1),
                    .init(icon: "arrow.left.arrow.right", label: "Transfers", tag: 2),
                    .init(icon: "person", label: "Profile", tag: 3)
                ]
            )
        }
    }
}