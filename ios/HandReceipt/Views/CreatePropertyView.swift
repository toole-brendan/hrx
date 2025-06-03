import SwiftUI
import PhotosUI

struct CreatePropertyView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreatePropertyViewModel
    
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingNSNSearch = false
    @State private var selectedImage: UIImage?
    @State private var showingSuccessAlert = false
    @State private var showingDuplicateAlert = false
    @State private var showingCancelConfirmation = false
    @State private var isShowingBarcodeScannerCreate = false
    
    // NSN Search states
    @State private var nsnSearchQuery = ""
    @State private var nsnSearchResults: [NSNDetails] = []
    @State private var isSearchingNSN = false
    
    // Form validation states
    @State private var serialNumberError: String?
    @State private var itemNameError: String?
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        self._viewModel = StateObject(wrappedValue: CreatePropertyViewModel(apiService: service))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                if #available(iOS 16.0, *) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Progress indicator
                            ProgressIndicator(currentStep: currentStep, totalSteps: 3)
                                .padding(.horizontal)
                            
                            // Photo Section
                            photoSection
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                // Serial Number Section
                                serialNumberSection
                                
                                // NSN/LIN Lookup Section
                                nsnLookupSection
                                
                                // Item Details Section
                                itemDetailsSection
                                
                                // Status and Assignment Section
                                statusAssignmentSection
                            }
                            
                            // Action Buttons
                            actionButtons
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Progress indicator
                            ProgressIndicator(currentStep: currentStep, totalSteps: 3)
                                .padding(.horizontal)
                            
                            // Photo Section
                            photoSection
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                // Serial Number Section
                                serialNumberSection
                                
                                // NSN/LIN Lookup Section
                                nsnLookupSection
                                
                                // Item Details Section
                                itemDetailsSection
                                
                                // Status and Assignment Section
                                statusAssignmentSection
                            }
                            
                            // Action Buttons
                            actionButtons
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Create Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isOffline {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                            Text("Offline")
                        }
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.warning)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingNSNSearch) {
                NSNSearchView(
                    searchQuery: $nsnSearchQuery,
                    searchResults: $nsnSearchResults,
                    isSearching: $isSearchingNSN,
                    onSelect: { details in
                        viewModel.applyNSNDetails(details)
                        showingNSNSearch = false
                    }
                )
            }
            .sheet(isPresented: $isShowingBarcodeScannerCreate) {
                BarcodeScannerView { barcode in
                    viewModel.serialNumber = barcode
                    isShowingBarcodeScannerCreate = false
                    validateSerialNumber()
                }
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("Create Another") {
                    resetForm()
                }
                Button("Done", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Property created successfully!")
            }
            .alert("Duplicate Serial Number", isPresented: $showingDuplicateAlert) {
                Button("OK") {
                    serialNumberError = "This serial number already exists"
                }
            } message: {
                Text("A property with this serial number already exists in the system.")
            }
            .alert("Unsaved Changes", isPresented: $showingCancelConfirmation) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentStep: Int {
        if !viewModel.serialNumber.isEmpty && !viewModel.itemName.isEmpty {
            return 3
        } else if !viewModel.serialNumber.isEmpty {
            return 2
        } else {
            return 1
        }
    }
    
    private var hasUnsavedChanges: Bool {
        !viewModel.serialNumber.isEmpty ||
        !viewModel.itemName.isEmpty ||
        !viewModel.description.isEmpty ||
        selectedImage != nil ||
        viewModel.selectedUser != nil
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(spacing: 12) {
            FormSectionHeader(title: "Property Photo", isOptional: true)
            
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                    
                    Button(action: { selectedImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .padding(8)
                }
            } else {
                HStack(spacing: 16) {
                    PhotoOptionButton(
                        icon: "camera.fill",
                        title: "Camera",
                        action: { showingCamera = true }
                    )
                    
                    PhotoOptionButton(
                        icon: "photo.fill",
                        title: "Library",
                        action: { showingImagePicker = true }
                    )
                }
            }
        }
    }
    
    // MARK: - Serial Number Section
    
    private var serialNumberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSectionHeader(title: "Serial Number", isRequired: true)
            
            HStack(spacing: 12) {
                TextField("Enter serial number", text: $viewModel.serialNumber)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.serialNumber) { _ in
                        validateSerialNumber()
                    }
                
                Button(action: { isShowingBarcodeScannerCreate = true }) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground)
                        .foregroundColor(AppColors.accent)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.accent, lineWidth: 1)
                        )
                }
            }
            
            if let error = serialNumberError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(AppFonts.caption)
                }
                .foregroundColor(AppColors.destructive)
            }
            
            Text("Unique identifier for this specific item")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
        }
    }
    
    // MARK: - NSN Lookup Section
    
    private var nsnLookupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                FormSectionHeader(title: "NSN/LIN Lookup", isOptional: true)
                Spacer()
                Text("AUTO-FILL FROM DATABASE")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.accent)
                    .kerning(AppFonts.wideKerning)
            }
            
            HStack(spacing: 12) {
                TextField("NSN or LIN (optional)", text: $viewModel.nsnLinInput)
                    .textFieldStyle(CustomTextFieldStyle())
                    .font(AppFonts.monoBody)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                
                Button(action: {
                    if viewModel.nsnLinInput.isEmpty {
                        showingNSNSearch = true
                    } else {
                        Task {
                            await viewModel.lookupNSNorLIN()
                        }
                    }
                }) {
                    Group {
                        if viewModel.isLookingUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: viewModel.nsnLinInput.isEmpty ? "magnifyingglass" : "arrow.right.circle.fill")
                                .font(.title2)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLookingUp)
            }
            
            if let nsnDetails = viewModel.nsnDetails {
                NSNDetailsCard(details: nsnDetails)
                    .transition(.opacity.combined(with: .scale))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Search or enter NSN/LIN to auto-populate item details")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
                
                // Visual emphasis box
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Text("Tap the search icon to browse the NSN database")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accent.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    // MARK: - Item Details Section
    
    private var itemDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Item Name
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader(title: "Item Name", isRequired: true)
                
                TextField("Enter item name", text: $viewModel.itemName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .onChange(of: viewModel.itemName) { _ in
                        validateItemName()
                    }
                
                if let error = itemNameError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(error)
                            .font(AppFonts.caption)
                    }
                    .foregroundColor(AppColors.destructive)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader(title: "Description", isOptional: true)
                
                IndustrialTextEditor(
                    text: $viewModel.description,
                    placeholder: "Add additional details about this item..."
                )
                .frame(height: 100)
            }
        }
    }
    
    // MARK: - Status and Assignment Section
    
    private var statusAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status Selection
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader(title: "Status", isRequired: true)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PropertyStatus.allCases, id: \.self) { status in
                            StatusSelectionPill(
                                status: status,
                                isSelected: viewModel.currentStatus == status
                            ) {
                                withAnimation {
                                    viewModel.currentStatus = status
                                }
                            }
                        }
                    }
                }
            }
            
            // Assign To
            VStack(alignment: .leading, spacing: 12) {
                FormSectionHeader(title: "Assign To", isOptional: true)
                
                if let assignedUser = viewModel.selectedUser {
                    AssignedUserCard(user: assignedUser) {
                        viewModel.selectedUser = nil
                    }
                } else {
                    Button(action: {
                        // TODO: Show user selection
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(AppColors.accent)
                            Text("Select user (optional)")
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                }
                
                if viewModel.selectedUser == nil {
                    Text("Leave empty to assign to yourself")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.tertiaryText)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if viewModel.isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("This property will be created locally and synced when online")
                }
                .font(AppFonts.caption)
                .foregroundColor(AppColors.warning)
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: createProperty) {
                Group {
                    if viewModel.isCreating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Creating...")
                        }
                    } else {
                        HStack {
                            Image(systemName: viewModel.isOffline ? "square.and.arrow.down" : "plus.circle.fill")
                            Text(viewModel.isOffline ? "Save Locally" : "Create Property")
                        }
                    }
                }
                .font(AppFonts.bodyBold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(viewModel.isCreating || !viewModel.isValid || serialNumberError != nil || itemNameError != nil)
        }
        .padding(.top)
    }
    
    // MARK: - Helper Methods
    
    private func validateSerialNumber() {
        serialNumberError = nil
        
        guard !viewModel.serialNumber.isEmpty else { return }
        
        if viewModel.serialNumber.count < 3 {
            serialNumberError = "Serial number must be at least 3 characters"
        } else if !viewModel.serialNumber.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
            serialNumberError = "Only letters, numbers, and hyphens allowed"
        }
        
        // TODO: Check for duplicates via API
    }
    
    private func validateItemName() {
        itemNameError = nil
        
        guard !viewModel.itemName.isEmpty else { return }
        
        if viewModel.itemName.count < 2 {
            itemNameError = "Item name must be at least 2 characters"
        }
    }
    
    private func createProperty() {
        Task {
            if await viewModel.createProperty(photo: selectedImage) {
                showingSuccessAlert = true
            }
        }
    }
    
    private func resetForm() {
        viewModel.serialNumber = ""
        viewModel.itemName = ""
        viewModel.description = ""
        viewModel.nsnLinInput = ""
        viewModel.nsnDetails = nil
        viewModel.selectedUser = nil
        viewModel.currentStatus = .operational
        selectedImage = nil
        serialNumberError = nil
        itemNameError = nil
    }
}

// MARK: - Supporting Views

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? AppColors.accent : AppColors.tertiaryBackground)
                    .frame(width: 8, height: 8)
                
                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? AppColors.accent : AppColors.tertiaryBackground)
                        .frame(height: 2)
                }
            }
        }
        .frame(height: 20)
    }
}

struct FormSectionHeader: View {
    let title: String
    var isRequired: Bool = false
    var isOptional: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(AppFonts.captionBold)
                .foregroundColor(AppColors.secondaryText)
                .compatibleKerning(1.2)
            
            if isRequired {
                Text("*")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.destructive)
            } else if isOptional {
                Text("(OPTIONAL)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
    }
}

struct PhotoOptionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(AppFonts.captionBold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
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

struct NSNDetailsCard: View {
    let details: NSNDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("NSN FOUND")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.success)
                    .compatibleKerning(1.2)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(details.nomenclature)
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                if let manufacturer = details.manufacturer {
                    HStack {
                        Text("Manufacturer:")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        Text(manufacturer)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                if let unitPrice = details.unitPrice {
                    HStack {
                        Text("Unit Price:")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                        Text("$\(String(format: "%.2f", unitPrice))")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.success.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
    }
}

struct StatusSelectionPill: View {
    let status: PropertyStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.title3)
                Text(status.displayName)
                    .font(AppFonts.captionBold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(isSelected ? .white : statusColor)
            .background(isSelected ? statusColor : statusColor.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(statusColor, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .operational: return AppColors.success
        case .nonOperational, .maintenance: return AppColors.warning
        case .missing, .damaged: return AppColors.destructive
        }
    }
}

struct AssignedUserCard: View {
    let user: UserSummary
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(AppColors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                Text("@\(user.username)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.secondaryText.opacity(0.2), lineWidth: 1)
            )
    }
}

// Barcode Scanner placeholder
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Camera view for barcode scanning")
                    .foregroundColor(AppColors.secondaryText)
                
                // Placeholder - implement actual barcode scanning
                Button("Simulate Scan") {
                    onScan("SN\(Int.random(in: 100000...999999))")
                }
                .buttonStyle(.primary)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class CreatePropertyViewModel: ObservableObject {
    let apiService: APIServiceProtocol
    
    @Published var serialNumber = ""
    @Published var itemName = ""
    @Published var description = ""
    @Published var currentStatus = PropertyStatus.operational
    @Published var nsnLinInput = ""
    @Published var selectedUser: UserSummary?
    @Published var nsnDetails: NSNDetails?
    
    @Published var isCreating = false
    @Published var isLookingUp = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    var isValid: Bool {
        !serialNumber.isEmpty && !itemName.isEmpty
    }
    
    func createProperty(photo: UIImage?) async -> Bool {
        guard isValid else { return false }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            let input = CreatePropertyInput(
                name: itemName,
                serialNumber: serialNumber,
                description: description.isEmpty ? nil : description,
                currentStatus: currentStatus.rawValue,
                propertyModelId: nil, // TODO: Get from NSN lookup
                assignedToUserId: selectedUser?.id,
                nsn: nsnDetails?.nsn,
                lin: nsnDetails?.lin
            )
            
            let property = try await apiService.createProperty(input)
            
            // Upload photo if provided
            if let photo = photo, let imageData = photo.jpegData(compressionQuality: 0.8) {
                do {
                    _ = try await apiService.uploadPropertyPhoto(propertyId: property.id, imageData: imageData)
                } catch {
                    // Photo upload failed, but property was created
                    print("Photo upload failed: \(error)")
                }
            }
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            return false
        }
    }
    
    func lookupNSNorLIN() async {
        guard !nsnLinInput.isEmpty else { return }
        
        isLookingUp = true
        defer { isLookingUp = false }
        
        do {
            // First check if it's a valid NSN format (13 digits with or without dashes)
            let cleanedInput = nsnLinInput.replacingOccurrences(of: "-", with: "")
            if cleanedInput.count == 13 && cleanedInput.allSatisfy({ $0.isNumber }) {
                // Try exact NSN lookup
                if let response = try? await apiService.lookupNSN(nsn: nsnLinInput) {
                    applyNSNDetails(response.data)
                    return
                }
            }
            
            // Otherwise, use universal search
            let searchResponse = try await apiService.universalSearchNSN(query: nsnLinInput, limit: 10)
            if searchResponse.data.isEmpty {
                errorMessage = "No items found for '\(nsnLinInput)'"
                showingError = true
            } else if searchResponse.data.count == 1 {
                // If only one result, apply it automatically
                applyNSNDetails(searchResponse.data[0])
            } else {
                // TODO: Show a selection sheet with multiple results
                // For now, just apply the first result
                applyNSNDetails(searchResponse.data[0])
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    func applyNSNDetails(_ details: NSNDetails) {
        nsnDetails = details
        itemName = details.nomenclature
        nsnLinInput = details.nsn
    }
}

// MARK: - Property Status Enum

enum PropertyStatus: String, CaseIterable {
    case operational = "Operational"
    case nonOperational = "Non-Operational"
    case maintenance = "Maintenance"
    case missing = "Missing"
    case damaged = "Damaged"
    
    var displayName: String {
        switch self {
        case .operational: return "Operational"
        case .nonOperational: return "Non-Op"
        case .maintenance: return "Maintenance"
        case .missing: return "Missing"
        case .damaged: return "Damaged"
        }
    }
}

// MARK: - Enhanced PropertyStatus
extension PropertyStatus {
    var icon: String {
        switch self {
        case .operational: return "checkmark.circle"
        case .nonOperational: return "xmark.circle"
        case .maintenance: return "wrench.and.screwdriver"
        case .missing: return "questionmark.circle"
        case .damaged: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Enhanced CreatePropertyViewModel
extension CreatePropertyViewModel {
    var isOffline: Bool {
        // TODO: Implement actual offline detection
        false
    }
} 