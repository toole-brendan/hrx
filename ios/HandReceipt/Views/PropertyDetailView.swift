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
                .navigationTitle("Property Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.property != nil {
                            Menu {
                                Button(action: { showingHistory = true }) {
                                    Label("View History", systemImage: "clock.arrow.circlepath")
                                }
                                
                                if viewModel.property?.needsMaintenance == true {
                                    Button(action: { showingMaintenanceSchedule = true }) {
                                        Label("Schedule Maintenance", systemImage: "wrench.and.screwdriver")
                                    }
                                }
                                
                                Divider()
                                
                                Button(action: { viewModel.requestTransferClicked() }) {
                                    Label("Request Transfer", systemImage: "arrow.left.arrow.right")
                                }
                                .disabled(viewModel.transferRequestState == .loading)
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                })
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
            ProgressView("Loading property details...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .success(let property):
            ScrollView {
                VStack(spacing: 20) {
                    // Photo section
                    propertyPhotoSection(property)
                    
                    // Primary info card
                    primaryInfoCard(property)
                    
                    // Technical details
                    technicalDetailsCard(property)
                    
                    // Status and location
                    statusLocationCard(property)
                    
                    // Offer to friends section (if user owns the property)
                    if let currentUserId = AuthManager.shared.getCurrentUserId(),
                       property.assignedToUserId == currentUserId {
                        offerToFriendsCard(property)
                    }
                    
                    // Maintenance info (if applicable)
                    if property.needsMaintenance || property.maintenanceDueDate != nil {
                        maintenanceCard(property)
                    }
                    
                    // Notes section
                    notesCard(property)
                    
                    // Audit trail preview
                    auditTrailCard(property)
                }
                .padding()
            }
            
        case .error(let message):
            ErrorStateView(message: message) {
                viewModel.loadProperty()
            }
        }
    }
    
    // MARK: - Section Views
    
    private func propertyPhotoSection(_ property: Property) -> some View {
        VStack(spacing: 12) {
            if let imageUrl = property.imageUrl, !imageUrl.isEmpty {
                // TODO: Implement AsyncImage for loading property photos
                Rectangle()
                    .fill(AppColors.secondaryBackground)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.tertiaryText)
                            Text("Property Photo")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    )
            } else {
                Button(action: { showingPhotoOptions = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                        Text("Add Photo")
                            .font(AppFonts.bodyBold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .foregroundColor(AppColors.accent)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(AppColors.accent.opacity(0.5))
                    )
                }
            }
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
    
    private func primaryInfoCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header with sensitive indicator
                HStack {
                    Text(property.itemName)
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    if property.isSensitive {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                            Text("SENSITIVE")
                                .font(AppFonts.captionBold)
                        }
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.warning.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                // Category indicator
                if let category = determineCategory(property) {
                    CategoryIndicator(category: category.name, iconName: category.icon)
                }
                
                // Description
                if let description = property.description, !description.isEmpty {
                    Text(description)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Manufacturer
                if let manufacturer = property.manufacturer {
                    HStack {
                        Text("Manufacturer:")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.tertiaryText)
                        Text(manufacturer)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                }
            }
            .padding()
        }
    }
    
    private func technicalDetailsCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("TECHNICAL DETAILS")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.2)
                
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
                }
            }
            .padding()
        }
    }
    
    private func statusLocationCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("STATUS & LOCATION")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.secondaryText)
                    .tracking(1.2)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Status")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        
                        StatusBadge(
                            status: property.status ?? property.currentStatus ?? "Unknown",
                            type: statusBadgeType(for: property.status ?? property.currentStatus ?? "Unknown")
                        )
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        
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
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                            Text(lastInvDate, formatter: dateFormatter)
                                .font(AppFonts.body)
                                .foregroundColor(verificationDateColor(lastInvDate))
                        }
                        
                        Spacer()
                        
                        Button(action: { /* Mark as inventoried */ }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Mark Inventoried")
                            }
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func offerToFriendsCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(AppColors.accent)
                        Text("TRANSFER OPTIONS")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.secondaryText)
                            .tracking(1.2)
                    }
                    Spacer()
                }
                
                Button(action: { showingOfferSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                        Text("Offer to Friends")
                    }
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Text("Send transfer offers to your connections")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private func maintenanceCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(AppColors.warning)
                        Text("MAINTENANCE REQUIRED")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.warning)
                            .tracking(1.2)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingMaintenanceSchedule = true }) {
                        Text("Schedule")
                            .font(AppFonts.captionBold)
                            .foregroundColor(AppColors.accent)
                    }
                }
                
                if let dueDate = property.maintenanceDueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due Date")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        Text(dueDate, formatter: dateFormatter)
                            .font(AppFonts.body)
                            .foregroundColor(maintenanceDateColor(dueDate))
                    }
                }
            }
            .padding()
            .overlay(
                Rectangle()
                    .stroke(AppColors.warning.opacity(0.5), lineWidth: 2)
            )
        }
    }
    
    private func notesCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NOTES")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    Spacer()
                    
                    Button(action: {
                        editedNotes = property.notes ?? ""
                        showingEditNotes = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(AppColors.accent)
                    }
                }
                
                if let notes = property.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No notes added")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.tertiaryText)
                        .italic()
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingEditNotes) {
            EditNotesView(notes: $editedNotes, onSave: {
                // TODO: Save notes via API
            })
        }
    }
    
    private func auditTrailCard(_ property: Property) -> some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AUDIT TRAIL")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.secondaryText)
                        .tracking(1.2)
                    
                    Spacer()
                    
                    Button(action: { showingHistory = true }) {
                        HStack(spacing: 4) {
                            Text("View All")
                            Image(systemName: "chevron.right")
                        }
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.accent)
                    }
                }
                
                // Show last 3 events preview
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3) { _ in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 6, height: 6)
                            
                            Text("Property created")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.primaryText)
                            
                            Spacer()
                            
                            Text("2 hours ago")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                    }
                }
            }
            .padding()
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

// MARK: - Supporting Views

struct PropertyHistoryView: View {
    let propertyId: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Placeholder for history items
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
                }
            }
            .listStyle(.plain)
            .navigationTitle("Property History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            })
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
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Schedule maintenance for:")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(property.itemName)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    
                    DatePicker(
                        "Maintenance Date",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .accentColor(AppColors.accent)
                    
                    IndustrialTextEditor(
                        text: $maintenanceNotes,
                        placeholder: "Add maintenance notes (optional)"
                    )
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.secondary)
                    
                    Button("Schedule") {
                        // TODO: Schedule maintenance via API
                        dismiss()
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding()
            .navigationTitle("Schedule Maintenance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EditNotesView: View {
    @Binding var notes: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                IndustrialTextEditor(
                    text: $notes,
                    placeholder: "Enter notes about this property..."
                )
                .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                    .font(AppFonts.bodyBold)
                }
            })
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
