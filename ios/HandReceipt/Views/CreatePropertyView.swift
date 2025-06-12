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
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation bar
                MinimalNavigationBar(
                    title: "Create Property",
                    titleStyle: .mono,
                    showBackButton: false,
                    trailingItems: [
                        .init(text: "Cancel", style: .text, action: {
                            if hasUnsavedChanges {
                                showingCancelConfirmation = true
                            } else {
                                dismiss()
                            }
                        })
                    ]
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Minimal progress indicator
                        StepProgressIndicator(currentStep: currentStep, totalSteps: 3)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        VStack(spacing: 20) {
                            // Photo Section
                            photoSection
                            
                            // Serial Number Section
                            serialNumberSection
                            
                            // NSN/LIN Lookup Section
                            nsnLookupSection
                            
                            // Item Details Section
                            itemDetailsSection
                            
                            // Status Section
                            statusSection
                            
                            // Assignment Section
                            assignmentSection
                        }
                        .padding(.horizontal, 20)
                        
                        // Action Buttons
                        actionButtons
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
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
            MinimalSectionHeader(title: "PHOTO", subtitle: "Optional")
            
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.tertiaryBackground)
                        .cornerRadius(4)
                    
                    Button(action: { selectedImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(AppColors.primaryText)
                            .background(Circle().fill(AppColors.secondaryBackground))
                    }
                    .padding(8)
                }
            } else {
                HStack(spacing: 12) {
                    MinimalPhotoButton(
                        icon: "camera",
                        title: "Camera",
                        action: { showingCamera = true }
                    )
                    
                    MinimalPhotoButton(
                        icon: "photo",
                        title: "Library",
                        action: { showingImagePicker = true }
                    )
                }
            }
        }
        .cleanCard(padding: 16)
    }
    
    // MARK: - Serial Number Section
    
    private var serialNumberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalSectionHeader(title: "SERIAL NUMBER", isRequired: true)
            
            HStack(spacing: 12) {
                MinimalTextField(
                    text: $viewModel.serialNumber,
                    placeholder: "Enter serial number",
                    font: .mono,
                    autocapitalization: .characters
                )
                .onChange(of: viewModel.serialNumber) { _ in
                    validateSerialNumber()
                }
                
                Button(action: { isShowingBarcodeScannerCreate = true }) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(AppColors.primaryText)
                        .frame(width: 44, height: 44)
                        .background(AppColors.tertiaryBackground)
                        .cornerRadius(4)
                }
            }
            
            if let error = serialNumberError {
                MinimalErrorText(error)
            }
        }
        .cleanCard(padding: 16)
    }
    
    // MARK: - NSN Lookup Section
    
    private var nsnLookupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MinimalSectionHeader(title: "NSN/LIN LOOKUP", subtitle: "Auto-fill from database")
                Spacer()
                if viewModel.isLookingUp {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                }
            }
            
            HStack(spacing: 12) {
                MinimalTextField(
                    text: $viewModel.nsnLinInput,
                    placeholder: "Search or enter NSN/LIN",
                    font: .mono
                )
                
                Button(action: {
                    if viewModel.nsnLinInput.isEmpty {
                        showingNSNSearch = true
                    } else {
                        Task {
                            await viewModel.lookupNSNorLIN()
                        }
                    }
                }) {
                    Image(systemName: viewModel.nsnLinInput.isEmpty ? "magnifyingglass" : "arrow.right")
                        .font(.system(size: 16, weight: .regular))
                }
                .buttonStyle(.minimalPrimary)
                .frame(width: 44, height: 44)
                .disabled(viewModel.isLookingUp)
            }
            
            if let nsnDetails = viewModel.nsnDetails {
                MinimalNSNDetailsCard(details: nsnDetails)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Help text
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(AppColors.accent)
                    Text("Tap search to browse the NSN database")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accentMuted)
                .cornerRadius(4)
            }
        }
        .cleanCard(padding: 16)
    }
    
    // MARK: - Item Details Section
    
    private var itemDetailsSection: some View {
        VStack(spacing: 16) {
            // Item Name
            VStack(alignment: .leading, spacing: 12) {
                MinimalSectionHeader(title: "ITEM NAME", isRequired: true)
                
                MinimalTextField(
                    text: $viewModel.itemName,
                    placeholder: "Enter item name"
                )
                .onChange(of: viewModel.itemName) { _ in
                    validateItemName()
                }
                
                if let error = itemNameError {
                    MinimalErrorText(error)
                }
            }
            .cleanCard(padding: 16)
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                MinimalSectionHeader(title: "DESCRIPTION", subtitle: "Optional")
                
                MinimalTextEditor(
                    text: $viewModel.description,
                    placeholder: "Add additional details...",
                    height: 80
                )
            }
            .cleanCard(padding: 16)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalSectionHeader(title: "STATUS", isRequired: true)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PropertyStatus.allCases, id: \.self) { status in
                        MinimalStatusPill(
                            status: status,
                            isSelected: viewModel.currentStatus == status
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.currentStatus = status
                            }
                        }
                    }
                }
            }
        }
        .cleanCard(padding: 16)
    }
    
    // MARK: - Assignment Section
    
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MinimalSectionHeader(title: "ASSIGN TO", subtitle: "Optional - defaults to you")
            
            if let assignedUser = viewModel.selectedUser {
                MinimalAssignedUserCard(user: assignedUser) {
                    viewModel.selectedUser = nil
                }
            } else {
                Button(action: {
                    // TODO: Show user selection
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(AppColors.secondaryText)
                        Text("Select user")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(12)
                    .background(AppColors.tertiaryBackground)
                    .cornerRadius(4)
                }
            }
        }
        .cleanCard(padding: 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                    Text("Will sync when online")
                        .font(AppFonts.caption)
                }
                .foregroundColor(AppColors.warning)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(AppColors.warning.opacity(0.1))
                .cornerRadius(4)
            }
            
            Button(action: createProperty) {
                Group {
                    if viewModel.isCreating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Creating...")
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isOffline ? "square.and.arrow.down" : "plus")
                                .font(.system(size: 16, weight: .regular))
                            Text(viewModel.isOffline ? "Save Locally" : "Create Property")
                        }
                    }
                }
                .font(AppFonts.bodyMedium)
            }
            .buttonStyle(.minimalPrimary)
            .disabled(viewModel.isCreating || !viewModel.isValid || serialNumberError != nil || itemNameError != nil)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    
    private func validateSerialNumber() {
        serialNumberError = nil
        
        guard !viewModel.serialNumber.isEmpty else { return }
        
        if viewModel.serialNumber.count < 3 {
            serialNumberError = "Must be at least 3 characters"
        } else if !viewModel.serialNumber.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
            serialNumberError = "Only letters, numbers, and hyphens"
        }
    }
    
    private func validateItemName() {
        itemNameError = nil
        
        guard !viewModel.itemName.isEmpty else { return }
        
        if viewModel.itemName.count < 2 {
            itemNameError = "Must be at least 2 characters"
        }
    }
    
    private func createProperty() {
        Task {
            // Check server for existing property with same serial number
            do {
                let _ = try await viewModel.apiService.getPropertyBySN(serialNumber: viewModel.serialNumber)
                // If we get here, property exists – show duplicate error
                showingDuplicateAlert = true
                return
            } catch let error as APIService.APIError where error == .itemNotFound {
                // OK: no existing property found, proceed with creation
            } catch {
                // Handle other errors (network, etc.) but still proceed
                print("Warning: Could not check for duplicate serial number: \(error)")
            }
            
            // Proceed to create since no duplicate was found
            if await viewModel.createProperty(photo: selectedImage) {
                // Trigger sync after successful creation
                OfflineSyncService.shared.startSync()
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

struct MinimalSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var isRequired: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(AppFonts.wideKerning)
            
            if isRequired {
                Text("*")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.destructive)
            }
            
            if let subtitle = subtitle {
                Text("• \(subtitle)")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            Spacer()
        }
    }
}

struct MinimalPhotoButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .light))
                Text(title)
                    .font(AppFonts.caption)
                    .kerning(AppFonts.wideKerning)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .foregroundColor(AppColors.secondaryText)
            .background(AppColors.tertiaryBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(AppColors.border)
            )
        }
    }
}

struct MinimalTextField: View {
    @Binding var text: String
    let placeholder: String
    var font: FontType = .sans
    var autocapitalization: TextInputAutocapitalization = .never
    
    enum FontType {
        case sans, mono
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(font == .mono ? AppFonts.monoBody : AppFonts.body)
            .padding(12)
            .background(AppColors.tertiaryBackground)
            .cornerRadius(4)
            .textInputAutocapitalization(autocapitalization)
            .disableAutocorrection(true)
    }
}

struct MinimalTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.tertiaryText)
                    .padding(12)
            }
            
            TextEditor(text: $text)
                .font(AppFonts.body)
                .padding(8)
                .background(AppColors.tertiaryBackground)
                .modifier(ScrollBackgroundModifier())
        }
        .frame(height: height)
        .cornerRadius(4)
    }
}

struct MinimalNSNDetailsCard: View {
    let details: NSNDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.success)
                Text("NSN FOUND")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.success)
                    .kerning(AppFonts.wideKerning)
            }
            
            Text(details.nomenclature)
                .font(AppFonts.bodyMedium)
                .foregroundColor(AppColors.primaryText)
            
            HStack(spacing: 16) {
                if let manufacturer = details.manufacturer {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MANUFACTURER")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.tertiaryText)
                            .kerning(AppFonts.wideKerning)
                        Text(manufacturer)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                if let unitPrice = details.unitPrice {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UNIT PRICE")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.tertiaryText)
                            .kerning(AppFonts.wideKerning)
                        Text("$\(String(format: "%.2f", unitPrice))")
                            .font(AppFonts.monoCaption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.success.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.success.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(4)
    }
}

struct MinimalStatusPill: View {
    let status: PropertyStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 16, weight: .light))
                Text(status.displayName.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .kerning(AppFonts.wideKerning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : AppColors.primaryText)
            .background(isSelected ? AppColors.primaryText : AppColors.tertiaryBackground)
            .cornerRadius(4)
        }
    }
}

struct MinimalAssignedUserCard: View {
    let user: UserSummary
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(AppColors.secondaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(user.rank ?? "") \(user.lastName ?? "")")
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                                        Text(user.email ?? "No email")
                    .font(AppFonts.monoCaption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
        .padding(12)
        .background(AppColors.tertiaryBackground)
        .cornerRadius(4)
    }
}

struct MinimalErrorText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
            Text(text)
                .font(AppFonts.caption)
        }
        .foregroundColor(AppColors.destructive)
    }
}

struct StepProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? AppColors.primaryText : AppColors.border)
                    .frame(width: 6, height: 6)
                
                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? AppColors.primaryText : AppColors.border)
                        .frame(height: 1)
                }
            }
        }
        .frame(height: 16)
    }
}

struct ScrollBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - BarcodeScannerView (Updated styling)
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                MinimalNavigationBar(
                    title: "Scan Barcode",
                    titleStyle: .mono,
                    showBackButton: false,
                    trailingItems: [
                        .init(text: "Cancel", style: .text, action: { dismiss() })
                    ]
                )
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Text("Camera view for barcode scanning")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                    
                    // Placeholder - implement actual barcode scanning
                    Button("Simulate Scan") {
                        onScan("SN\(Int.random(in: 100000...999999))")
                    }
                    .buttonStyle(.minimalPrimary)
                    
                    Spacer()
                }
                .padding(20)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Existing ViewModels and Extensions remain the same

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
    
    func checkDuplicate() async -> Bool {
        guard !serialNumber.isEmpty else { return false }
        do {
            let _ = try await apiService.getPropertyBySN(serialNumber: serialNumber)
            return true  // Found a property with this serial
        } catch let apiError as APIService.APIError {
            if apiError == .itemNotFound {
                return false  // No duplicate found
            }
            // On other errors (network, etc.) we could either treat as "no duplicate" or surface an error
            return false
        } catch {
            return false
        }
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
                propertyModelId: nil,
                assignedToUserId: selectedUser?.id,
                nsn: nsnDetails?.nsn,
                lin: nsnDetails?.lin
            )
            
            let property = try await apiService.createProperty(input)
            
            if let photo = photo, let imageData = photo.jpegData(compressionQuality: 0.8) {
                do {
                    _ = try await apiService.uploadPropertyPhoto(propertyId: property.id, imageData: imageData)
                } catch {
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
            let cleanedInput = nsnLinInput.replacingOccurrences(of: "-", with: "")
            if cleanedInput.count == 13 && cleanedInput.allSatisfy({ $0.isNumber }) {
                if let response = try? await apiService.lookupNSN(nsn: nsnLinInput) {
                    applyNSNDetails(response.data)
                    return
                }
            }
            
            let searchResponse = try await apiService.universalSearchNSN(query: nsnLinInput, limit: 10)
            if searchResponse.data.isEmpty {
                errorMessage = "No items found for '\(nsnLinInput)'"
                showingError = true
            } else if searchResponse.data.count == 1 {
                applyNSNDetails(searchResponse.data[0])
            } else {
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

extension CreatePropertyViewModel {
    var isOffline: Bool {
        // TODO: Implement actual offline detection
        false
    }
}