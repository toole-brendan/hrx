Recommendations for Surfacing New Features
Based on the analysis from document 10, here's how to better integrate your new features into the redesigned UI:
1. DA 2062 Import/Export
Currently, the DA2062ScanView and DA2062ExportView exist but aren't accessible in the UI. In your new minimalist design:
swift// Add to MyPropertiesView navigation bar
MinimalNavigationBar(
    title: "PROPERTY",
    titleStyle: .mono,
    trailingItems: [
        .init(icon: "plus", action: showAddMenu),  // Changed from direct create
        .init(icon: "doc.text.viewfinder", action: showDA2062Scan),
        .init(icon: "line.3.horizontal.decrease", action: showFilters)
    ]
)

// Replace single Add button with menu
Menu {
    Button("Create New Property", action: createProperty)
    Button("Import from DA-2062", action: showDA2062Scan)
} label: {
    Image(systemName: "plus")
        .font(.system(size: 20, weight: .light))
}
2. Maintenance Form Request
The SendMaintenanceFormView exists but is hidden - users must go through the Maintenance screen. Add direct access:
swift// In PropertyDetailView's toolbar
MinimalToolbar(items: [
    .init(icon: "arrow.left.arrow.right", label: "Transfer", action: initiateTransfer),
    .init(icon: "doc.plaintext", label: "Maintenance Form", action: showMaintenanceForm),  // NEW
    .init(icon: "qrcode", label: "QR Code", action: showQR)
])
3. Documents Inbox
Currently only accessible via Maintenance > View Maintenance Forms. Make it more prominent:
swift// Add badge to Profile tab when unread documents exist
MinimalTabBar.TabItem(
    icon: "person",
    label: "PROFILE",
    tag: 3,
    badge: documentService.unreadCount > 0 ? "\(documentService.unreadCount)" : nil
)

// Or add dedicated section in Dashboard
struct DashboardView: View {
    var body: some View {
        // ... existing sections ...
        
        // New inbox card with 8VC styling
        if documentService.unreadCount > 0 {
            NavigationLink(destination: DocumentsView()) {
                HStack {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 24, weight: .light))
                    VStack(alignment: .leading) {
                        Text("Documents Inbox")
                            .font(AppFonts.bodyMedium)
                        Text("\(documentService.unreadCount) unread")
                            .font(AppFonts.monoCaption)  // Monospace for numbers
                    }
                    Spacer()
                }
                .cleanCard()
            }
        }
    }
}
4. NSN Lookup Enhancement
NSN lookup exists in Create Property but might not be immediately apparent. Make it more discoverable:
swift// In CreatePropertyView, add visual emphasis
VStack(alignment: .leading, spacing: 16) {
    Text("AUTO-FILL FROM DATABASE")
        .font(AppFonts.captionMedium)
        .foregroundColor(AppColors.secondaryText)
        .kerning(AppFonts.ultraWideKerning)
    
    HStack {
        TextField("Search NSN/LIN", text: $nsnSearchText)
            .font(AppFonts.monoBody)  // Monospace for technical data
        
        Button(action: showNSNSearch) {
            Label("Search Database", systemImage: "magnifyingglass")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.minimalSecondary)
    }
    .padding(12)
    .background(AppColors.accentMuted)  // Light blue background to draw attention
    .cornerRadius(4)
}