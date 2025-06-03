// handreceipt/ios/HandReceipt/Views/PropertyDetailView.swift

import SwiftUI
import PhotosUI

struct PropertyDetailView: View {
    @StateObject private var viewModel: PropertyDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingEditNotes = false
    @State private var editedNotes = ""
    @State private var showingPhotoOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var showingMenu = false

    @State private var showingHistory = false
    @State private var showingMaintenanceSchedule = false
    @State private var showingOfferSheet = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    init(propertyId: Int, apiService: APIServiceProtocol = APIService()) {
        let vm = PropertyDetailViewModel(propertyId: propertyId, apiService: apiService)
        self._viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            content
                .industrialNavigation(
                    title: "Property Details",
                    showBackButton: true,
                    backButtonAction: { dismiss() },
                    trailingItems: [
                        .init(icon: "ellipsis", action: { showingMenu = true })
                    ]
                )
                .sheet(isPresented: $viewModel.showingUserSelection) {
                    UserSelectionView(onUserSelected: { selectedUser in
                        viewModel.initiateTransfer(targetUser: selectedUser)
                    })
                }
                .sheet(isPresented: $showingHistory) {
                    if let property = viewModel.property {
                        PropertyHistoryView(propertyId: property.id)
                    }
                }
                .sheet(isPresented: $showingMaintenanceSchedule) {
                    if let property = viewModel.property {
                        MaintenanceScheduleView(property: property)
                    }
                }
                .sheet(isPresented: $showingOfferSheet) {
                    if let property = viewModel.property {
                        OfferPropertyView(property: property)
                    }
                }
                .confirmationDialog("Property Actions", isPresented: $showingMenu) {
                    Button("View History") { showingHistory = true }
                    
                    if viewModel.property?.needsMaintenance == true {
                        Button("Schedule Maintenance") { showingMaintenanceSchedule = true }
                    }
                    
                    Button("Request Transfer") { viewModel.requestTransferClicked() }
                        .disabled(viewModel.transferRequestState == .loading)
                    
                    Button("Cancel", role: .cancel) { }
                }
                .overlay(TransferStatusMessage(state: viewModel.transferRequestState))
        }
        .onAppear {
            viewModel.loadProperty()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            IndustrialLoadingView(message: "LOADING PROPERTY")
            
        case .success(let property):
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    heroSection(property)
                    
                    // Quick Actions
                    quickActionsSection(property)
                    
                    // Details Sections with improved spacing
                    VStack(spacing: 20) {
                        technicalDetailsCard(property)
                        statusLocationCard(property)
                        auditTrailCard(property)
                    }
                    .padding(.horizontal)
                }
            }
            
        case .error(let message):
            ModernEmptyStateView(
                icon: "exclamationmark.triangle",
                title: "Error Loading",
                message: message,
                actionTitle: "RETRY",
                action: { viewModel.loadProperty() }
            )
        }
    }
    
    // MARK: - Enhanced Section Views
    
    private func heroSection(_ property: Property) -> some View {
        VStack(spacing: 16) {
            // Property Image or Placeholder with enhanced styling
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.secondaryBackground, AppColors.tertiaryBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                
                if property.imageUrl == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("TAP TO ADD PHOTO")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.secondaryText)
                            .compatibleKerning(AppFonts.militaryTracking)
                    }
                }
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .onTapGesture {
                showingPhotoOptions = true
            }
            
            // Property Title Section with enhanced typography
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(property.itemName)
                            .font(AppFonts.largeTitleHeavy)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(property.serialNumber)
                            .font(AppFonts.monoLarge)
                            .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    if property.isSensitive {
                        StatusBadge(status: "SENSITIVE", type: .warning, size: .large)
                    }
                }
                
                if let category = determineCategory(property) {
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                        Text(category.name.uppercased())
                            .font(AppFonts.captionHeavy)
                            .compatibleKerning(AppFonts.militaryTracking)
                    }
                    .foregroundColor(categoryColor(for: category.name))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(categoryColor(for: category.name).opacity(0.1))
                    .cornerRadius(4)
                }
                
                // Description with better spacing
                if let description = property.description, !description.isEmpty {
                    Text(description)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
        }
        .actionSheet(isPresented: $showingPhotoOptions) {
            ActionSheet(
                title: Text("Add Property Photo"),
                buttons: [
                    .default(Text("Take Photo")) { showingCamera = true },
                    .default(Text("Choose from Library")) { showingImagePicker = true },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
        }
    }
    
    private func quickActionsSection(_ property: Property) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "arrow.left.arrow.right",
                    title: "TRANSFER",
                    color: AppColors.accent,
                    action: { viewModel.requestTransferClicked() }
                )
                
                QuickActionButton(
                    icon: "wrench.and.screwdriver",
                    title: "MAINTENANCE",
                    color: AppColors.warning,
                    action: { showingMaintenanceSchedule = true }
                )
                
                QuickActionButton(
                    icon: "clock.arrow.circlepath",
                    title: "HISTORY",
                    color: AppColors.success,
                    action: { showingHistory = true }
                )
                
                if let currentUserId = AuthManager.shared.getUserId(),
                   property.assignedToUserId == currentUserId {
                    QuickActionButton(
                        icon: "gift",
                        title: "OFFER",
                        color: AppColors.tacticalGreen,
                        action: { showingOfferSheet = true }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func technicalDetailsCard(_ property: Property) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(title: "Technical Details", subtitle: "Property specifications and identifiers")
            
            VStack(spacing: 12) {
                TechnicalDataField(label: "NSN", value: property.nsn ?? "Not Available")
                
                if let lin = property.lin {
                    TechnicalDataField(label: "LIN", value: lin)
                }
                
                TechnicalDataField(label: "Serial Number", value: property.serialNumber)
                
                if let acquisitionDate = property.acquisitionDate {
                    TechnicalDataField(
                        label: "Acquisition Date",
                        value: dateFormatter.string(from: acquisitionDate)
                    )
                }
                
                if let manufacturer = property.manufacturer {
                    TechnicalDataField(label: "Manufacturer", value: manufacturer)
                }
            }
        }
        .modernCard(isElevated: false)
    }
    
    private func statusLocationCard(_ property: Property) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(title: "Status & Location", subtitle: "Current operational status and location")
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Status")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.tertiaryText)
                        .compatibleKerning(AppFonts.wideTracking)
                    
                    StatusBadge(
                        status: property.status ?? property.currentStatus ?? "Unknown",
                        type: statusBadgeType(for: property.status ?? property.currentStatus ?? "Unknown"),
                        size: .medium
                    )
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.tertiaryText)
                        .compatibleKerning(AppFonts.wideTracking)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                        Text(property.location ?? "Not specified")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
            }
            
            if let lastInvDate = property.lastInventoryDate {
                IndustrialDivider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Verification")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                            .compatibleKerning(AppFonts.wideTracking)
                        Text(lastInvDate, formatter: dateFormatter)
                            .font(AppFonts.body)
                            .foregroundColor(verificationDateColor(lastInvDate))
                    }
                    
                    Spacer()
                    
                    Button(action: { /* Mark as inventoried */ }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text("MARK INVENTORIED")
                        }
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.accent)
                        .compatibleKerning(AppFonts.wideTracking)
                    }
                }
            }
            
            // Maintenance section if needed
            if property.needsMaintenance || property.maintenanceDueDate != nil {
                IndustrialDivider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.warning)
                            Text("MAINTENANCE REQUIRED")
                                .font(AppFonts.captionHeavy)
                                .foregroundColor(AppColors.warning)
                                .compatibleKerning(AppFonts.militaryTracking)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingMaintenanceSchedule = true }) {
                            Text("SCHEDULE")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.accent)
                                .compatibleKerning(AppFonts.wideTracking)
                        }
                    }
                    
                    if let dueDate = property.maintenanceDueDate {
                        TechnicalDataField(
                            label: "Due Date",
                            value: dateFormatter.string(from: dueDate)
                        )
                    }
                }
                .padding(12)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .modernCard(isElevated: false)
    }
    
    private func auditTrailCard(_ property: Property) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ModernSectionHeader(
                title: "Audit Trail",
                subtitle: "Recent property activity",
                action: { showingHistory = true },
                actionLabel: "View All"
            )
            
            // Show last 3 events preview with enhanced styling
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3) { index in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.2))
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 8, height: 8)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Property created")
                                .font(AppFonts.bodyBold)
                                .foregroundColor(AppColors.primaryText)
                            
                            Text("by SGT Johnson")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text("\(index + 2) hours ago")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    
                    if index < 2 {
                        Divider()
                            .background(AppColors.border)
                    }
                }
            }
            
            // Notes section if available
            if let notes = property.notes, !notes.isEmpty {
                IndustrialDivider(title: "Notes")
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notes)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        editedNotes = notes
                        showingEditNotes = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
            } else {
                IndustrialDivider(title: "Notes")
                
                Button(action: {
                    editedNotes = ""
                    showingEditNotes = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("ADD NOTES")
                            .font(AppFonts.captionBold)
                            .compatibleKerning(AppFonts.wideTracking)
                    }
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .modernCard(isElevated: false)
        .sheet(isPresented: $showingEditNotes) {
            EditNotesView(notes: $editedNotes, onSave: {
                // TODO: Save notes via API
            })
        }
    }
    
    // MARK: - Helper Methods
    
    private func determineCategory(_ property: Property) -> (name: String, icon: String)? {
        let name = property.itemName.lowercased()
        
        if name.contains("weapon") || name.contains("rifle") || name.contains("pistol") {
            return ("Weapons", "shield.lefthalf.filled")
        } else if name.contains("radio") || name.contains("comm") {
            return ("Communications", "antenna.radiowaves.left.and.right")
        } else if name.contains("optic") || name.contains("nvg") || name.contains("scope") {
            return ("Optics", "eye")
        } else if name.contains("vehicle") || name.contains("truck") {
            return ("Vehicles", "car.fill")
        } else if name.contains("computer") || name.contains("electronic") {
            return ("Electronics", "desktopcomputer")
        }
        
        return nil
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "weapons": return AppColors.weaponsCategory
        case "communications": return AppColors.communicationsCategory
        case "optics": return AppColors.opticsCategory
        case "vehicles": return AppColors.vehiclesCategory
        case "electronics": return AppColors.electronicsCategory
        default: return AppColors.secondaryText
        }
    }
    
    private func statusBadgeType(for status: String) -> StatusBadge.StatusType {
        switch status.lowercased() {
        case "operational": return .success
        case "maintenance", "non-operational": return .warning
        case "missing": return .error
        default: return .neutral
        }
    }
    
    private func verificationDateColor(_ date: Date) -> Color {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysSince > 90 {
            return AppColors.destructive
        } else if daysSince > 30 {
            return AppColors.warning
        } else {
            return AppColors.success
        }
    }
    
    private func maintenanceDateColor(_ date: Date) -> Color {
        if date < Date() {
            return AppColors.destructive
        } else if date < Date().addingTimeInterval(7 * 24 * 60 * 60) {
            return AppColors.warning
        } else {
            return AppColors.secondaryText
        }
    }
}

// MARK: - Supporting Views with Enhanced Styling

// Modifier to handle scrollContentBackground compatibility
struct ScrollContentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
        } else {
            content
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
        }
    }
}

struct PropertyHistoryView: View {
    let propertyId: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                List {
                    ForEach(0..<10) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Transfer Completed")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Spacer()
                                
                                Text("\(index + 1) days ago")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.tertiaryText)
                            }
                            
                            Text("From: SPC Smith → To: SGT Johnson")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(AppColors.secondaryBackground)
                    }
                }
                .listStyle(.plain)
                .modifier(ScrollContentBackgroundModifier())
            }
            .industrialNavigation(
                title: "Property History",
                showBackButton: true,
                backButtonAction: { dismiss() }
            )
        }
    }
}

struct MaintenanceScheduleView: View {
    let property: Property
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var maintenanceNotes = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSectionHeader(
                            title: "Schedule Maintenance",
                            subtitle: "Set up maintenance for \(property.itemName)"
                        )
                        
                        DatePicker(
                            "Maintenance Date",
                            selection: $selectedDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .accentColor(AppColors.accent)
                        .modernCard()
                        
                        IndustrialTextEditor(
                            text: $maintenanceNotes,
                            placeholder: "Add maintenance notes (optional)"
                        )
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button("CANCEL") {
                            dismiss()
                        }
                        .buttonStyle(.secondary)
                        
                        Button("SCHEDULE") {
                            // TODO: Schedule maintenance via API
                            dismiss()
                        }
                        .buttonStyle(.primary)
                    }
                }
                .padding()
            }
            .industrialNavigation(
                title: "Schedule Maintenance",
                showBackButton: true,
                backButtonAction: { dismiss() }
            )
        }
    }
}

struct EditNotesView: View {
    @Binding var notes: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    ModernSectionHeader(
                        title: "Property Notes",
                        subtitle: "Add or edit notes about this property"
                    )
                    
                    IndustrialTextEditor(
                        text: $notes,
                        placeholder: "Enter notes about this property..."
                    )
                    .frame(minHeight: 200)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button("CANCEL") {
                            dismiss()
                        }
                        .buttonStyle(.secondary)
                        
                        Button("SAVE") {
                            onSave()
                            dismiss()
                        }
                        .buttonStyle(.primary)
                    }
                }
                .padding()
            }
            .industrialNavigation(
                title: "Edit Notes",
                showBackButton: true,
                backButtonAction: { dismiss() }
            )
        }
    }
}

// MARK: - Preview
struct PropertyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PropertyDetailView(propertyId: 1, apiService: APIService())
        }
        .preferredColorScheme(.dark)
    }
}
