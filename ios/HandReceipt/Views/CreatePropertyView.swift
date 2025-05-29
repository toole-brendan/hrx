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
    
    init(apiService: APIServiceProtocol? = nil) {
        let service = apiService ?? APIService()
        self._viewModel = StateObject(wrappedValue: CreatePropertyViewModel(apiService: service))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Photo Section
                        photoSection
                        
                        // Form Fields
                        formFields
                        
                        // Submit Button
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingNSNSearch) {
                NSNSearchView(viewModel: viewModel)
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Property created successfully!")
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
    
    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(spacing: 12) {
            Text("Property Photo")
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .overlay(
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                HStack(spacing: 16) {
                    photoButton(icon: "camera.fill", title: "Camera") {
                        showingCamera = true
                    }
                    
                    photoButton(icon: "photo.fill", title: "Library") {
                        showingImagePicker = true
                    }
                }
            }
        }
    }
    
    private func photoButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(AppFonts.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .foregroundColor(AppColors.accent)
            .background(AppColors.secondaryBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 16) {
            // Serial Number (Required)
            FormField(
                label: "Serial Number *",
                text: $viewModel.serialNumber,
                placeholder: "Enter serial number",
                isRequired: true
            )
            
            // Item Name (Required)
            FormField(
                label: "Item Name *",
                text: $viewModel.itemName,
                placeholder: "Enter item name",
                isRequired: true
            )
            
            // NSN/LIN Lookup
            VStack(alignment: .leading, spacing: 8) {
                Text("NSN/LIN Lookup")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                HStack(spacing: 12) {
                    TextField("NSN or LIN", text: $viewModel.nsnLinInput)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    Button(action: {
                        if viewModel.nsnLinInput.isEmpty {
                            showingNSNSearch = true
                        } else {
                            Task {
                                await viewModel.lookupNSNorLIN()
                            }
                        }
                    }) {
                        if viewModel.isLookingUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: viewModel.nsnLinInput.isEmpty ? "magnifyingglass" : "arrow.right.circle.fill")
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                if let nsnDetails = viewModel.nsnDetails {
                    NSNDetailsView(details: nsnDetails)
                        .transition(.opacity)
                }
            }
            
            // Description (Optional)
            FormField(
                label: "Description",
                text: $viewModel.description,
                placeholder: "Enter description (optional)",
                isRequired: false,
                isMultiline: true
            )
            
            // Status (Required)
            VStack(alignment: .leading, spacing: 8) {
                Text("Status *")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                Picker("Status", selection: $viewModel.currentStatus) {
                    ForEach(PropertyStatus.allCases, id: \.self) { status in
                        Text(status.displayName)
                            .tag(status)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Assign To (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign To")
                    .font(AppFonts.bodyBold)
                    .foregroundColor(AppColors.primaryText)
                
                if let assignedUser = viewModel.selectedUser {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(assignedUser.rank ?? "") \(assignedUser.lastName ?? "")")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                            Text(assignedUser.username)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.selectedUser = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(8)
                } else {
                    Button(action: { /* TODO: Show user selection */ }) {
                        HStack {
                            Text("Select user (optional)")
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: {
            Task {
                if await viewModel.createProperty(photo: selectedImage) {
                    showingSuccessAlert = true
                }
            }
        }) {
            if viewModel.isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
            } else {
                Text("Create Property")
                    .font(AppFonts.bodyBold)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.primary)
        .disabled(viewModel.isCreating || !viewModel.isValid)
        .padding(.top)
    }
}

// MARK: - Supporting Views

struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let isRequired: Bool
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.bodyBold)
                .foregroundColor(AppColors.primaryText)
            
            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(AppColors.secondaryBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.secondaryText.opacity(0.2), lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            }
        }
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

struct NSNDetailsView: View {
    let details: NSNDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("NSN Found")
                    .font(AppFonts.captionBold)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(details.nomenclature)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
                
                if let manufacturer = details.manufacturer {
                    Text("Manufacturer: \(manufacturer)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                if let unitPrice = details.unitPrice {
                    Text("Unit Price: $\(String(format: "%.2f", unitPrice))")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.secondaryBackground.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

// MARK: - NSN Search View

struct NSNSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePropertyViewModel
    @State private var searchQuery = ""
    @State private var searchResults: [NSNDetails] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    HStack {
                        TextField("Search NSN/LIN database", text: $searchQuery)
                            .textFieldStyle(CustomTextFieldStyle())
                            .onSubmit {
                                Task {
                                    await performSearch()
                                }
                            }
                        
                        Button(action: {
                            Task {
                                await performSearch()
                            }
                        }) {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    // Results
                    if searchResults.isEmpty && !isSearching {
                        Spacer()
                        Text("Search for items by name, NSN, or LIN")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                        Spacer()
                    } else {
                        List(searchResults, id: \.nsn) { item in
                            Button(action: {
                                viewModel.applyNSNDetails(item)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.nomenclature)
                                        .font(AppFonts.bodyBold)
                                        .foregroundColor(AppColors.primaryText)
                                    Text("NSN: \(item.nsn)")
                                        .font(AppFonts.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    if let lin = item.lin {
                                        Text("LIN: \(lin)")
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("NSN/LIN Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
    
    private func performSearch() async {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        do {
            let response = try await viewModel.apiService.searchNSN(query: searchQuery, limit: 50)
            searchResults = response.data
        } catch {
            // Handle error
            print("Search error: \(error)")
        }
        isSearching = false
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
            // Try NSN first, then LIN
            if let response = try? await apiService.lookupNSN(nsn: nsnLinInput) {
                applyNSNDetails(response.data)
            } else if let response = try? await apiService.lookupLIN(lin: nsnLinInput) {
                applyNSNDetails(response.data)
            } else {
                errorMessage = "NSN/LIN not found"
                showingError = true
            }
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

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
} 