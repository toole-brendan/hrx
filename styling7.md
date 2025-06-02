# Navigation Implementation Guide for 8VC-Style iOS App

## Navigation Principles

### 1. **Minimalism Over Decoration**
- Remove all gradients, shadows, and heavy borders
- Use thin 1px dividers instead of elevation
- Prefer light-weight icons (SF Symbols with `.light` weight)
- Reduce visual noise - no unnecessary badges or decorations

### 2. **Typography Hierarchy**
- **Hidden**: No title for immersive views (Dashboard)
- **Serif**: Elegant, important screens (Property Details)
- **Mono**: Technical/data screens (Transfers, Logs)
- **Minimal**: Standard navigation (Settings, Lists)
- **Hero**: Feature screens that need emphasis

### 3. **Spacing & Breathing Room**
- 24px horizontal padding (increased from typical 16px)
- 16px vertical padding for nav bars
- 20px spacing between nav items
- Generous whitespace around titles

## Screen-Specific Implementations

### Dashboard
```swift
struct DashboardView: View {
    var body: some View {
        VStack(spacing: 0) {
            // No title, just brand mark and profile
            MinimalNavigationBar(
                titleStyle: .hidden,
                trailingItems: [
                    .init(icon: "bell", action: showNotifications),
                    .init(icon: "person.circle", action: showProfile)
                ]
            )
            
            ScrollView {
                // Dashboard content
            }
        }
        .navigationBarHidden(true)
    }
}
```

### Property List
```swift
struct MyPropertiesView: View {
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "PROPERTY",
                titleStyle: .mono,  // Technical, all-caps with spacing
                trailingItems: [
                    .init(icon: "plus", action: createProperty),
                    .init(icon: "line.3.horizontal.decrease", action: showFilters)
                ]
            )
            
            // Inline header for context
            InlinePageHeader(
                title: "Equipment Inventory",
                subtitle: "127 items tracked",
                style: .standard
            )
            
            List {
                // Property items
            }
        }
    }
}
```

### Property Detail
```swift
struct PropertyDetailView: View {
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "M4 Carbine",
                titleStyle: .serif,  // Elegant for important items
                showBackButton: true,
                backAction: { presentationMode.wrappedValue.dismiss() },
                trailingItems: [
                    .init(icon: "square.and.arrow.up", action: shareProperty)
                ]
            )
            
            ScrollView {
                // Property details
            }
            
            // Contextual actions at bottom
            MinimalToolbar(items: [
                .init(icon: "arrow.left.arrow.right", label: "Transfer", action: initiateTransfer),
                .init(icon: "qrcode", label: "QR Code", action: showQR),
                .init(icon: "wrench", label: "Service", action: scheduleMaintenance)
            ])
        }
    }
}
```

### Transfers
```swift
struct TransfersView: View {
    @State private var selectedFilter = 0
    
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "TRANSFERS",
                titleStyle: .mono,
                trailingItems: [
                    .init(text: "History", style: .text, action: showHistory)
                ]
            )
            
            // Subtle filter tabs
            HStack(spacing: 32) {
                FilterTab(title: "Pending", isSelected: selectedFilter == 0)
                    .onTapGesture { selectedFilter = 0 }
                FilterTab(title: "Sent", isSelected: selectedFilter == 1)
                    .onTapGesture { selectedFilter = 1 }
                FilterTab(title: "Received", isSelected: selectedFilter == 2)
                    .onTapGesture { selectedFilter = 2 }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(AppColors.tertiaryBackground)
            
            List {
                // Transfer items
            }
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
            
            Rectangle()
                .fill(isSelected ? AppColors.primaryText : Color.clear)
                .frame(height: 2)
        }
    }
}
```

### Settings/Profile
```swift
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            MinimalNavigationBar(
                title: "Settings",
                titleStyle: .minimal,
                showBackButton: true,
                backAction: { /* dismiss */ }
            )
            
            List {
                Section {
                    // User info at top
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppColors.tertiaryBackground)
                            .frame(width: 60, height: 60)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPT John Smith")
                                .font(AppFonts.headline)
                            Text("john.smith@army.mil")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppColors.secondaryBackground)
                
                // Settings sections...
            }
            .listStyle(InsetGroupedListStyle())
            .background(AppColors.appBackground)
        }
    }
}
```

## Tab Bar Implementation

Replace the heavy tab bar with minimal version:

```swift
struct AuthenticatedTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(0)
                
                MyPropertiesView()
                    .tag(1)
                
                TransfersView()
                    .tag(2)
                
                ProfileView()
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom minimal tab bar
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
```

## Modal Presentations

For modals, use a simplified header:

```swift
struct CreatePropertySheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Simple header for modals
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(TextLinkButtonStyle())
                    
                    Spacer()
                    
                    Text("New Property")
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Button("Save") {
                        // Save action
                    }
                    .buttonStyle(TextLinkButtonStyle())
                    .disabled(!isValid)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                Divider()
                
                Form {
                    // Form content
                }
            }
            .navigationBarHidden(true)
        }
    }
}
```

## Best Practices

### DO:
- ✅ Use consistent 24px horizontal padding
- ✅ Keep navigation items to 2-3 maximum
- ✅ Use text links for secondary actions
- ✅ Match title style to content type
- ✅ Use thin dividers to separate sections
- ✅ Prefer icons without labels in nav bars

### DON'T:
- ❌ Use heavy shadows or gradients
- ❌ Stack multiple navigation levels
- ❌ Use bright colors for non-critical items
- ❌ Mix too many font styles in navigation
- ❌ Overcrowd the navigation bar
- ❌ Use system navigation bars - always hide and use custom

## Transitions

When implementing, consider smooth transitions:

```swift
// Subtle fade transition between views
.transition(.opacity.combined(with: .move(edge: .trailing)))
.animation(.easeInOut(duration: 0.3), value: selectedTab)
```

## Accessibility

Ensure all custom navigation maintains accessibility:

```swift
MinimalBackButton(action: goBack)
    .accessibilityLabel("Go back")
    .accessibilityHint("Returns to previous screen")

NavItem(icon: "bell", action: showNotifications)
    .accessibilityLabel("Notifications")
    .accessibilityHint("Shows pending notifications")
```