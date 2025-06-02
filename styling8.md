// NavigationComparison.swift - Visual comparison of old vs new navigation styles
import SwiftUI

struct NavigationComparisonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 60) {
                // Title
                Text("Navigation Transformation")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .padding(.top, 40)
                
                // Dashboard Navigation
                ComparisonSection(
                    title: "Dashboard Navigation",
                    oldView: OldDashboardNav(),
                    newView: NewDashboardNav()
                )
                
                // Property Detail Navigation
                ComparisonSection(
                    title: "Property Detail Navigation",
                    oldView: OldPropertyNav(),
                    newView: NewPropertyNav()
                )
                
                // Tab Bar Comparison
                ComparisonSection(
                    title: "Tab Bar",
                    oldView: OldTabBar(),
                    newView: NewTabBar()
                )
                
                // Key Changes Summary
                KeyChangesCard()
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(hex: "FAFAFA"))
    }
}

// MARK: - Comparison Section Component
struct ComparisonSection<OldView: View, NewView: View>: View {
    let title: String
    let oldView: OldView
    let newView: NewView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
            
            HStack(spacing: 20) {
                // Before
                VStack(alignment: .leading, spacing: 12) {
                    Label("BEFORE", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .labelStyle(IconLabelStyle())
                    
                    oldView
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                }
                
                // After
                VStack(alignment: .leading, spacing: 12) {
                    Label("AFTER", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .labelStyle(IconLabelStyle())
                    
                    newView
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                }
            }
        }
    }
}

// MARK: - Old Navigation Styles (Current)
struct OldDashboardNav: View {
    var body: some View {
        HStack {
            Text("DASHBOARD")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .tracking(2)
            
            Spacer()
            
            HStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "00D4FF"))
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "00D4FF"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "1A1A1A"))
    }
}

struct OldPropertyNav: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text("Back")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color(hex: "00D4FF"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "00D4FF").opacity(0.1))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "00D4FF").opacity(0.3), lineWidth: 1)
                )
            }
            
            Spacer()
            
            Text("PROPERTY DETAIL")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .tracking(1.5)
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "00D4FF"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "1A1A1A"))
    }
}

struct OldTabBar: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(["house.fill", "shippingbox.fill", "arrow.left.arrow.right.circle.fill", "person.fill"], id: \.self) { icon in
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(icon == "house.fill" ? Color(hex: "00D4FF") : Color.gray)
                    
                    Rectangle()
                        .fill(icon == "house.fill" ? Color(hex: "00D4FF") : Color.clear)
                        .frame(height: 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(hex: "0F0F0F"))
        .overlay(
            Rectangle()
                .fill(Color(hex: "2A2A2A"))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - New Navigation Styles (8VC-inspired)
struct NewDashboardNav: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text("HR")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(Color(hex: "6B6B6B"))
                
                Spacer()
                
                HStack(spacing: 20) {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.black)
                    
                    Image(systemName: "person.circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(hex: "F0F0F0"))
                .frame(height: 1)
        }
    }
}

struct NewPropertyNav: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .regular))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Color(hex: "4A4A4A"))
                }
                
                Spacer()
                
                Text("M4 Carbine")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Rectangle()
                .fill(Color(hex: "F0F0F0"))
                .frame(height: 1)
        }
    }
}

struct NewTabBar: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "F0F0F0"))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                ForEach([
                    ("house", "HOME"),
                    ("shippingbox", "PROPERTY"),
                    ("arrow.left.arrow.right", "TRANSFERS"),
                    ("person", "PROFILE")
                ], id: \.0) { icon, label in
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: icon == "house" ? .regular : .light))
                            .foregroundColor(icon == "house" ? .black : Color(hex: "9B9B9B"))
                        
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(icon == "house" ? .black : Color(hex: "9B9B9B"))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Key Changes Card
struct KeyChangesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Key Navigation Changes")
                .font(.system(size: 20, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 16) {
                ChangeItem(
                    icon: "paintbrush",
                    title: "Color Palette",
                    description: "From dark theme with neon accents to light, monochromatic design"
                )
                
                ChangeItem(
                    icon: "textformat",
                    title: "Typography",
                    description: "Mixed serif, sans-serif, and monospace fonts for hierarchy"
                )
                
                ChangeItem(
                    icon: "square.dashed",
                    title: "Borders & Shadows",
                    description: "Replaced heavy borders with 1px dividers, minimal shadows"
                )
                
                ChangeItem(
                    icon: "arrow.left.and.right.text.vertical",
                    title: "Spacing",
                    description: "Increased padding from 16px to 24px, more breathing room"
                )
                
                ChangeItem(
                    icon: "minus.circle",
                    title: "Visual Weight",
                    description: "Light font weights, thin icons, reduced visual noise"
                )
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
}

struct ChangeItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Color(hex: "0066CC"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Custom label style
struct IconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

// Preview
struct NavigationComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationComparisonView()
    }
}