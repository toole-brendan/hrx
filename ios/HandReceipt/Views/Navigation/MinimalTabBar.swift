// MinimalTabBar.swift - Extracted from NavigationComponents.swift
import SwiftUI

// MARK: - Tab Bar Alternative (Bottom Navigation)
public struct MinimalTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    
    public struct TabItem {
        let icon: String
        let label: String
        let tag: Int
        let badge: String?
        
        public init(icon: String, label: String, tag: Int, badge: String? = nil) {
            self.icon = icon
            self.label = label
            self.tag = tag
            self.badge = badge
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
                    ZStack {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: isSelected ? .regular : .light))
                            .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                        
                        // Badge indicator
                        if let badge = item.badge {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text(badge)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -8)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    Text(item.label.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                        .compatibleKerning(AppFonts.wideKerning)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
} 