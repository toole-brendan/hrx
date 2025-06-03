import SwiftUI
import PhotosUI

struct SendMaintenanceFormView: View {
    let property: Property
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SendMaintenanceFormViewModel()
    @State private var selectedForm: MaintenanceFormData.FormType = .da2404
    @State private var selectedRecipient: UserSummary?
    @State private var description = ""
    @State private var faultDescription = ""
    @State private var selectedPhoto: UIImage?
    @State private var showingPhotoPicker = false
    @State private var showingConnectionPicker = false
    @State private var connections: [UserConnection] = []
    @State private var isLoadingConnections = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Property Info Card
                    propertyInfoCard
                    
                    // Form Type Selection
                    formSelectionSection
                    
                    // Assign To Section
                    assignToSection
                    
                    // Description
                    descriptionSection
                    
                    // Fault Description
                    faultDescriptionSection
                    
                    // Photos
                    photoSection
                }
                .padding()
            }
            .background(AppColors.appBackground)
            .navigationTitle("Send Maintenance Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        Task { await sendForm() }
                    }
                    .disabled(!isValid || viewModel.isLoading)
                }
            }
        }
        .sheet(isPresented: $showingConnectionPicker) {
            ConnectionPickerView(
                connections: connections.filter { $0.connectionStatus == .accepted },
                onSelect: { user in
                    selectedRecipient = user
                    showingConnectionPicker = false
                }
            )
        }
        .sheet(isPresented: $showingPhotoPicker) {
                                        MaintenanceImagePicker(image: $selectedPhoto)
        }
        .task {
            await loadConnections()
        }
        .alert("Success", isPresented: .constant(viewModel.showSuccessMessage)) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: .constant(viewModel.showErrorMessage)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var propertyInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EQUIPMENT INFORMATION")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(property.itemName)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                HStack {
                    Text("SN: \(property.serialNumber)")
                        .font(AppFonts.mono)
                        .foregroundColor(AppColors.secondaryText)
                    
                    if let nsn = property.nsn {
                        Divider()
                            .frame(height: 16)
                        
                        Text("NSN: \(nsn)")
                            .font(AppFonts.mono)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .font(AppFonts.caption)
            }
        }
        .padding()
        .background(AppColors.secondaryBackground)
        .overlay(
            Rectangle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
    
    private var formSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORM TYPE")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            VStack(spacing: 12) {
                ForEach(MaintenanceFormData.FormType.allCases, id: \.self) { formType in
                    Button(action: { selectedForm = formType }) {
                        HStack {
                            Image(systemName: formType.icon)
                                .frame(width: 20, height: 20)
                                .foregroundColor(selectedForm == formType ? AppColors.accent : AppColors.tertiaryText)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formType.rawValue)
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text(formType.description)
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            if selectedForm == formType {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .overlay(
                            Rectangle()
                                .stroke(selectedForm == formType ? AppColors.accent : AppColors.border, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var assignToSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SEND TO")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            if let recipient = selectedRecipient {
                HStack {
                    UserAvatarView(user: recipient, size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(recipient.rank ?? "") \(recipient.name)")
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        Text(recipient.unit ?? "")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        showingConnectionPicker = true
                    }
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.accent)
                }
                .padding()
                .background(AppColors.secondaryBackground)
                .overlay(
                    Rectangle()
                        .stroke(AppColors.border, lineWidth: 1)
                )
            } else {
                Button(action: { showingConnectionPicker = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(AppColors.tertiaryText)
                        Text("Select Recipient")
                            .foregroundColor(AppColors.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding()
                    .background(AppColors.secondaryBackground)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DESCRIPTION *")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            ZStack(alignment: .topLeading) {
                // Background color
                AppColors.secondaryBackground
                
                TextEditor(text: $description)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
    }
    
    private var faultDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAULT DESCRIPTION (OPTIONAL)")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            ZStack(alignment: .topLeading) {
                // Background color
                AppColors.secondaryBackground
                
                TextEditor(text: $faultDescription)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHOTO (OPTIONAL)")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .kerning(1.2)
            
            if let photo = selectedPhoto {
                VStack(spacing: 12) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                    
                    HStack {
                        Button("Remove") {
                            selectedPhoto = nil
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Change") {
                            showingPhotoPicker = true
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    .font(AppFonts.caption)
                }
            } else {
                Button(action: { showingPhotoPicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("Add Photo")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(AppColors.secondaryBackground)
                    .overlay(
                        Rectangle()
                            .stroke(AppColors.border, lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var isValid: Bool {
        selectedRecipient != nil && !description.isEmpty
    }
    
    private func sendForm() async {
        guard let recipient = selectedRecipient else { return }
        
        await viewModel.sendMaintenanceForm(
            property: property,
            recipient: recipient,
            formType: selectedForm,
            description: description,
            faultDescription: faultDescription.isEmpty ? nil : faultDescription,
            photo: selectedPhoto
        )
    }
    
    private func loadConnections() async {
        isLoadingConnections = true
        
        do {
            connections = try await APIService.shared.getConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
        
        isLoadingConnections = false
    }
}

// MARK: - Supporting Views

struct ConnectionPickerView: View {
    let connections: [UserConnection]
    let onSelect: (UserSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(connections, id: \.id) { connection in
                if let user = connection.connectedUser {
                    Button(action: { onSelect(user) }) {
                        HStack {
                            UserAvatarView(user: user, size: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(user.rank ?? "") \(user.name)")
                                    .font(AppFonts.bodyBold)
                                    .foregroundColor(AppColors.primaryText)
                                Text(user.unit ?? "")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Recipient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct UserAvatarView: View {
    let user: UserSummary
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(AppColors.accent.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(user.name.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            )
    }
}

struct MaintenanceImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MaintenanceImagePicker
        
        init(_ parent: MaintenanceImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
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

// MARK: - ViewModel

@MainActor
class SendMaintenanceFormViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showSuccessMessage = false
    @Published var showErrorMessage = false
    @Published var successMessage = ""
    @Published var errorMessage = ""
    
    func sendMaintenanceForm(
        property: Property,
        recipient: UserSummary,
        formType: MaintenanceFormData.FormType,
        description: String,
        faultDescription: String?,
        photo: UIImage?
    ) async {
        isLoading = true
        
        do {
            let request = CreateMaintenanceFormRequest(
                propertyId: property.id,
                recipientUserId: recipient.id,
                formType: formType.rawValue,
                description: description,
                faultDescription: faultDescription,
                attachments: photo != nil ? ["photo_placeholder_url"] : nil
            )
            
            _ = try await DocumentService.shared.sendMaintenanceForm(request)
            
            successMessage = "Maintenance form sent to \(recipient.rank ?? "") \(recipient.name)"
            showSuccessMessage = true
            
        } catch {
            errorMessage = "Failed to send maintenance form: \(error.localizedDescription)"
            showErrorMessage = true
        }
        
        isLoading = false
    }
    
    func clearError() {
        showErrorMessage = false
        errorMessage = ""
    }
} 