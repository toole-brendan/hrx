//
//  PropertyDetailView.swift
//  HandReceipt
//
//  8VC-inspired property detail view with minimal toolbar
//

import SwiftUI

// MARK: - Property Detail View
struct PropertyDetailView: View {
    let property: Property
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PropertyDetailViewModel()
    
    // View states
    @State private var selectedSection = 0
    @State private var showTransferSheet = false
    @State private var showQRCode = false
    @State private var showMaintenanceSheet = false
    @State private var showActionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            MinimalNavigationBar(
                title: property.itemName,
                titleStyle: .serif,
                showBackButton: true,
                backAction: { dismiss() },
                trailingItems: [
                    .init(icon: "square.and.arrow.up", action: shareProperty),
                    .init(icon: "ellipsis", action: { showActionSheet = true })
                ]
            )
            
            // Content
            ScrollView {
                VStack(spacing: 40) {
                    // Hero section
                    heroSection
                    
                    // Information sections
                    VStack(spacing: 32) {
                        detailsSection
                        historySection
                        maintenanceSection
                        documentsSection
                    }
                    .padding(.horizontal, 24)
                    
                    // Bottom padding for toolbar
                    Color.clear.frame(height: 100)
                }
            }
            .overlay(alignment: .bottom) {
                // Minimal toolbar
                MinimalToolbar(items: [
                    .init(icon: "arrow.left.arrow.right", label: "Transfer", action: { showTransferSheet = true }),
                    .init(icon: "qrcode", label: "QR Code", action: { showQRCode = true }),
                    .init(icon: "wrench", label: "Service", action: { showMaintenanceSheet = true }),
                    .init(icon: "doc.text", label: "Report", action: generateReport)
                ])
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTransferSheet) {
            TransferInitiationSheet(property: property)
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeSheet(property: property)
        }
        .sheet(isPresented: $showMaintenanceSheet) {
            MaintenanceScheduleSheet(property: property)
        }
        .confirmationDialog("More Actions", isPresented: $showActionSheet) {
            Button("Edit Property") { editProperty() }
            Button("View Audit Log") { viewAuditLog() }
            Button("Export Data") { exportData() }
            Button("Report Issue", role: .destructive) { reportIssue() }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack {
            // Geometric background pattern
            GeometricPatternView()
                .frame(height: 240)
                .opacity(0.05)
            
            VStack(spacing: 24) {
                // Property identifier
                VStack(spacing: 8) {
                    Text("SERIAL NUMBER")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                        .kerning(AppFonts.ultraWideKerning)
                    
                    Text(property.serialNumber)
                        .font(AppFonts.monoHeadline)
                        .foregroundColor(AppColors.primaryText)
                }
                
                // Status indicator
                PropertyStatusBadge(
                    status: property.status,
                    style: .large
                )
                
                // Key metrics
                HStack(spacing: 32) {
                    MetricItem(
                        value: property.condition,
                        label: "CONDITION"
                    )
                    
                    MetricItem(
                        value: property.lastVerified.formatted(.relative(presentation: .named)),
                        label: "VERIFIED"
                    )
                    
                    MetricItem(
                        value: "\(property.transferCount)",
                        label: "TRANSFERS"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .background(AppColors.secondaryBackground)
        .cornerRadius(8)
        .shadow(color: AppColors.shadowColor, radius: 4, y: 2)
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ElegantSectionHeader(
                title: "DETAILS",
                style: .uppercase
            )
            
            VStack(spacing: 0) {
                InfoRow(
                    label: "Category",
                    value: property.category.uppercased(),
                    style: .mono
                )
                
                Divider()
                    .background(AppColors.divider)
                
                InfoRow(
                    label: "NSN",
                    value: property.nsn ?? "Not Available",
                    style: .mono
                )
                
                Divider()
                    .background(AppColors.divider)
                
                InfoRow(
                    label: "Location",
                    value: property.location,
                    style: .standard
                )
                
                Divider()
                    .background(AppColors.divider)
                
                InfoRow(
                    label: "Current Holder",
                    value: property.currentHolder.name,
                    style: .standard,
                    accessory: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                )
            }
            .cleanCard(padding: 0)
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ElegantSectionHeader(
                title: "TRANSFER HISTORY",
                subtitle: "\(viewModel.transfers.count) transfers",
                style: .uppercase,
                action: viewModel.transfers.count > 3 ? { viewAllTransfers() } : nil,
                actionLabel: "View All"
            )
            
            if viewModel.isLoadingTransfers {
                SkeletonLoadingView(rows: 3)
            } else if viewModel.transfers.isEmpty {
                MinimalEmptyState(
                    icon: "clock",
                    title: "No Transfer History",
                    message: "This property has not been transferred yet"
                )
                .cleanCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.transfers.prefix(3)) { transfer in
                        TransferHistoryRow(transfer: transfer)
                        
                        if transfer.id != viewModel.transfers.prefix(3).last?.id {
                            Divider()
                                .background(AppColors.divider)
                                .padding(.leading, 56)
                        }
                    }
                }
                .cleanCard(padding: 0)
            }
        }
    }
    
    // MARK: - Maintenance Section
    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ElegantSectionHeader(
                title: "MAINTENANCE",
                subtitle: property.nextMaintenance != nil ? "Next service due" : "No maintenance scheduled",
                style: .uppercase
            )
            
            if let nextMaintenance = property.nextMaintenance {
                MaintenanceCard(
                    date: nextMaintenance,
                    type: property.maintenanceType,
                    isOverdue: nextMaintenance < Date()
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "wrench")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundColor(AppColors.tertiaryText)
                    
                    Text("No maintenance scheduled")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Button("Schedule Maintenance") {
                        showMaintenanceSheet = true
                    }
                    .buttonStyle(MinimalSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .cleanCard()
            }
        }
    }
    
    // MARK: - Documents Section
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ElegantSectionHeader(
                title: "DOCUMENTS",
                subtitle: "\(viewModel.documents.count) files",
                style: .uppercase,
                action: { uploadDocument() },
                actionLabel: "Upload"
            )
            
            if viewModel.documents.isEmpty {
                MinimalEmptyState(
                    icon: "doc",
                    title: "No Documents",
                    message: "Upload technical manuals, receipts, or other documentation"
                )
                .cleanCard()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.documents) { document in
                        DocumentRow(document: document)
                    }
                }
                .cleanCard()
            }
        }
    }
    
    // MARK: - Actions
    private func shareProperty() {
        // Share implementation
    }
    
    private func generateReport() {
        // Report generation
    }
    
    private func editProperty() {
        // Edit implementation
    }
    
    private func viewAuditLog() {
        // Audit log navigation
    }
    
    private func exportData() {
        // Export implementation
    }
    
    private func reportIssue() {
        // Issue reporting
    }
    
    private func viewAllTransfers() {
        // Navigate to full transfer history
    }
    
    private func uploadDocument() {
        // Document upload
    }
}

// MARK: - Supporting Components

struct MetricItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.monoBody)
                .foregroundColor(AppColors.primaryText)
            
            Text(label)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
        }
    }
}

struct InfoRow<Accessory: View>: View {
    let label: String
    let value: String
    let style: TextStyle
    let accessory: (() -> Accessory)?
    
    enum TextStyle {
        case standard
        case mono
        
        var font: Font {
            switch self {
            case .standard: return AppFonts.body
            case .mono: return AppFonts.monoBody
            }
        }
    }
    
    init(label: String, value: String, style: TextStyle = .standard, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.label = label
        self.value = value
        self.style = style
        self.accessory = accessory
    }
    
    init(label: String, value: String, style: TextStyle = .standard) where Accessory == EmptyView {
        self.label = label
        self.value = value
        self.style = style
        self.accessory = nil
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(style.font)
                    .foregroundColor(AppColors.primaryText)
                
                if let accessory = accessory {
                    accessory()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct TransferHistoryRow: View {
    let transfer: Transfer
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(AppColors.tertiaryBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transferIcon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(AppColors.secondaryText)
                )
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transfer.description)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                Text(transfer.participants)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            // Date
            Text(transfer.date.formatted(.relative(presentation: .named)))
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
        .padding(16)
    }
    
    private var transferIcon: String {
        switch transfer.type {
        case .incoming: return "arrow.down.circle"
        case .outgoing: return "arrow.up.circle"
        case .maintenance: return "wrench"
        case .verification: return "checkmark.circle"
        }
    }
}

struct MaintenanceCard: View {
    let date: Date
    let type: String
    let isOverdue: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.uppercased())
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .kerning(AppFonts.wideKerning)
                    
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                }
                
                Spacer()
                
                if isOverdue {
                    Label("Overdue", systemImage: "exclamationmark.circle")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.destructive)
                }
            }
            
            // Progress to maintenance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Time until service")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                    
                    Text(isOverdue ? "Overdue" : date.formatted(.relative(presentation: .named)))
                        .font(AppFonts.monoCaption)
                        .foregroundColor(isOverdue ? AppColors.destructive : AppColors.primaryText)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.tertiaryBackground)
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(isOverdue ? AppColors.destructive : AppColors.primaryText)
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    }
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
        }
        .padding(20)
        .cleanCard()
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard !isOverdue else { return totalWidth }
        
        let totalDays = 365.0 // Assuming annual maintenance
        let daysUntil = date.timeIntervalSinceNow / 86400
        let progress = max(0, min(1, 1 - (daysUntil / totalDays)))
        
        return totalWidth * CGFloat(progress)
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                Text("\(document.size) • \(document.uploadDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
            
            Button(action: { downloadDocument(document) }) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.accent)
            }
        }
    }
    
    private func downloadDocument(_ document: Document) {
        // Download implementation
    }
}

// MARK: - Property Status Badge
struct PropertyStatusBadge: View {
    let status: PropertyStatus
    let style: BadgeStyle
    
    enum BadgeStyle {
        case small
        case large
        
        var font: Font {
            switch self {
            case .small: return AppFonts.caption
            case .large: return AppFonts.body
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
            case .large: return EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
            }
        }
    }
    
    var body: some View {
        Text(status.displayName.uppercased())
            .font(style.font)
            .foregroundColor(status.color)
            .kerning(AppFonts.wideKerning)
            .padding(style.padding)
            .background(status.color.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(status.color.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - View Model
class PropertyDetailViewModel: ObservableObject {
    @Published var transfers: [Transfer] = []
    @Published var documents: [Document] = []
    @Published var isLoadingTransfers = true
    @Published var isLoadingDocuments = true
    
    init() {
        // Load data
    }
}

// MARK: - Preview
struct PropertyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PropertyDetailView(property: .sample)
    }
}