import SwiftUI
import UIKit

// Disable emoji keyboard to prevent RTIInputSystemClient errors
extension UITextField {
    open override var textInputMode: UITextInputMode? {
        // Disable emoji keyboard to prevent RTIInputSystemClient errors
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                return nil
            }
        }
        return super.textInputMode
    }
}

struct DA2062ExportView: View {
    @StateObject private var viewModel = DA2062ExportViewModel()
    @State private var showingShareSheet = false
    @State private var showingRecipientInput = false

    @State private var generatedPDF: Data?
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showingUnitInfoEditor = false
    @State private var showingRecipientPicker = false
    @State private var selectedConnection: UserConnection?
    @State private var showingSignatureCapture = false
    @State private var signatureImage: UIImage?
    @StateObject private var connectionsViewModel = ConnectionsViewModel(apiService: APIService.shared)
    @Environment(\.dismiss) private var dismiss
    
    let preSelectedPropertyIDs: [Int]
    
    init(preSelectedPropertyIDs: [Int] = []) {
        self.preSelectedPropertyIDs = preSelectedPropertyIDs
    }
    
    var body: some View {
        ZStack {
            // Light background
            AppColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom navigation bar
                MinimalNavigationBar(
                    title: "Export DA 2062",
                    titleStyle: .mono,
                    showBackButton: false,
                    trailingItems: [
                        .init(text: "Cancel", style: .text, action: { dismiss() })
                    ]
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Unit Information Section
                        unitInfoSection
                        
                        // Property Selection Section
                        propertySelectionSection
                        
                        // Signature Section
                        signatureSection
                        
                        // Export Options Section
                        exportOptionsSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            
            if isGenerating {
                MinimalLoadingOverlay(message: "Generating DA 2062...")
            }
        }
        .keyboardAdaptive() // Add keyboard handling
        .ignoresSafeArea(.keyboard, edges: .bottom) // Add proper keyboard handling
        .navigationBarHidden(true)

        .sheet(isPresented: $showingShareSheet) {
            if let pdfData = generatedPDF {
                ShareSheet(items: [pdfData])
            }
        }
        .alert("Export Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("✅ Success", isPresented: $showSuccess) {
            Button("OK") { 
                // Dismiss the view after successful operations
                if successMessage.contains("Hand Receipt sent") || successMessage.contains("DA 2062 sent") {
                    dismiss()
                }
            }
        } message: {
            Text(successMessage)
        }
        .sheet(isPresented: $showingUnitInfoEditor) {
            UnitInfoEditorView(unitInfo: $viewModel.unitInfo)
        }
        .sheet(isPresented: $showingSignatureCapture) {
            SignatureCaptureView { image in 
                AppLogger.debug("SignatureCaptureView onSave callback called")
                // Callback on save: persist image and upload
                saveSignatureImage(image)
            }
        }

        .sheet(isPresented: $showingRecipientPicker) {
            NavigationView {
                VStack {
                    // Header with Cancel and Send
                    HStack {
                        Button("Cancel") { showingRecipientPicker = false }
                            .padding(.leading)
                        Spacer()
                        Text("Send Hand Receipt")
                            .font(.headline)
                        Spacer()
                        Button("Send") {
                            Task { await sendHandReceiptInApp() }
                        }
                        .disabled(selectedConnection == nil)
                        .padding(.trailing)
                    }
                    .padding(.vertical)
                    Divider()
                    // List connections
                    ScrollView {
                        VStack(spacing: 0) {
                            if connectionsViewModel.connections.isEmpty {
                                Text("No connections available").padding()
                            }
                            ForEach(connectionsViewModel.connections) { connection in
                                Button(action: {
                                    selectedConnection = connection
                                    viewModel.recipientConnection = connection   // new: keep selection in ViewModel
                                }) {
                                    HStack {
                                        Text(connection.connectedUser?.name ?? "Unknown")
                                        Spacer()
                                        Image(systemName: selectedConnection?.id == connection.id 
                                                ? "checkmark.circle.fill" 
                                                : "circle")
                                            .foregroundColor(AppColors.accent)
                                    }
                                    .padding()
                                }
                                .background(selectedConnection?.id == connection.id 
                                            ? AppColors.accent.opacity(0.1) 
                                            : Color.clear)
                            }
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        }
        .task {
            if !preSelectedPropertyIDs.isEmpty {
                await viewModel.loadUserPropertiesAndSetSelection(preSelectedPropertyIDs)
            } else {
                await viewModel.loadUserProperties()
            }
            // Load saved signature if available
            loadSavedSignature()
        }
    }
    
    // MARK: - View Components
    
    private var unitInfoSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Unit Information",
                subtitle: "Organization details for this hand receipt",
                style: .serif,
                action: { showingUnitInfoEditor = true },
                actionLabel: "Edit"
            )
            
            VStack(spacing: 12) {
                MinimalInfoRow(label: "UNIT", value: viewModel.unitInfo.unitName, valueFont: .mono)
                MinimalInfoRow(label: "DODAAC", value: viewModel.unitInfo.dodaac, valueFont: .mono)
                MinimalInfoRow(label: "LOCATION", value: viewModel.unitInfo.location)
            }
            .cleanCard(padding: 16)
        }
    }
    
    private var propertySelectionSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Select Properties",
                subtitle: "\(viewModel.selectedPropertyIDs.count) of \(viewModel.properties.count) items selected",
                style: .serif
            )
            
            if viewModel.properties.isEmpty {
                CompactEmptyState(
                    icon: "shippingbox",
                    title: "No Properties Available",
                    message: "You don't have any properties to export"
                )
                .padding(.vertical, 32)
                .cleanCard(showShadow: false)
            } else {
                VStack(spacing: 16) {
                    // Quick actions with minimal styling
                    HStack(spacing: 20) {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        .buttonStyle(.textLink)
                        
                        Button("Clear") {
                            viewModel.clearSelection()
                        }
                        .buttonStyle(.textLink)
                        
                        Spacer()
                        
                        Menu {
                            Button("Weapons Only") {
                                viewModel.selectCategory("weapons")
                            }
                            Button("Equipment Only") {
                                viewModel.selectCategory("equipment")
                            }
                            Button("Sensitive Items") {
                                viewModel.selectSensitiveItems()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("FILTER")
                                    .font(AppFonts.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .kerning(AppFonts.wideKerning)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(AppColors.secondaryText)
                            }
                        }
                    }
                    
                    // Property list with minimal cards
                    VStack(spacing: 8) {
                        ForEach(viewModel.properties) { property in
                            MinimalPropertySelectionRow(
                                property: property,
                                isSelected: viewModel.selectedPropertyIDs.contains(property.id),
                                onToggle: {
                                    viewModel.toggleSelection(for: property.id)
                                }
                            )
                        }
                    }
                }
                .cleanCard(padding: 16)
            }
        }
    }
    
    private var signatureSection: some View {
        VStack(spacing: 16) {
            // Section header with an Edit/Add action
            ElegantSectionHeader(
                title: "Signature",
                subtitle: "Your digital signature",
                style: .serif,
                action: { showingSignatureCapture = true },
                actionLabel: signatureImage != nil ? "Edit" : "Add"
            )
            
            // Display either the saved signature or a placeholder
            VStack(spacing: 12) {
                if let sigImage = signatureImage {
                    VStack(spacing: 8) {
                        // Signature preview header
                        HStack {
                            Text("Signature Preview")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Spacer()
                            
                            Text("As Written")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        // Signature with rotation preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                                )
                            
                                                         // Signature displayed horizontally for readability
                             GeometryReader { geometry in
                                 Image(uiImage: sigImage)
                                     .resizable()
                                     .scaledToFit()
                                     .frame(maxHeight: 80)
                                     .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                             }
                            .frame(height: 120)
                        }
                        .shadow(color: AppColors.shadowColor.opacity(0.1), radius: 2, y: 1)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "signature")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                        
                        Text("No signature saved")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("Tap 'Add' to draw your signature")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(.vertical, 32)
                }
            }
            .cleanCard(padding: 16)
        }
    }
    
    private var exportOptionsSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Export Options",
                style: .uppercase
            )
            
            VStack(spacing: 0) {
                // Recipient selection row
                Button(action: {
                    Task { 
                        await MainActor.run { 
                            connectionsViewModel.loadConnections() 
                        }
                        showingRecipientPicker = true 
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recipient")
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.primaryText)
                            Text(selectedConnection?.connectedUser?.name ?? "Select a recipient")
                                .font(AppFonts.caption)
                                .foregroundColor(selectedConnection == nil ? AppColors.destructive : AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(AppColors.tertiaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                

            }
            .cleanCard(padding: 0)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: generateAndShare) {
                HStack {
                    Image(systemName: selectedConnection != nil ? "paperplane.fill" : "doc.pdf")
                        .font(.system(size: 16, weight: .regular))
                    Text(selectedConnection != nil ? "Send Hand Receipt" : "Generate PDF")
                        .font(AppFonts.bodyMedium)
                }
            }
            .buttonStyle(.minimalPrimary)
            .disabled(viewModel.selectedPropertyIDs.isEmpty || signatureImage == nil)
            
            Button(action: { 
                Task {
                    await MainActor.run { 
                        connectionsViewModel.loadConnections() 
                    }
                    showingRecipientPicker = true 
                }
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .regular))
                    Text("Send to User")
                        .font(AppFonts.bodyMedium)
                }
            }
            .buttonStyle(.minimalSecondary)
            .disabled(viewModel.selectedPropertyIDs.isEmpty || signatureImage == nil)
        }
    }
    
    // MARK: - Helper Methods
    

    
    private func loadSavedSignature() {
        guard let userId = AuthManager.shared.getUserId() else {
            AppLogger.debug("Failed to get user ID when loading signature")
            return
        }
        
        AppLogger.debug("Loading signature for user ID: \(userId)")
        
        let fileName = "signature_\(userId).png"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                signatureImage = image
                AppLogger.info("Signature loaded successfully")
            } else {
                AppLogger.warning("Failed to load signature image data")
            }
        } else {
            AppLogger.debug("No saved signature found")
        }
    }
    
    private func saveSignatureImage(_ image: UIImage) {
        AppLogger.debug("saveSignatureImage called with image size: \(image.size)")
        
        guard let pngData = image.pngData() else {
            AppLogger.error("Failed to convert image to PNG data")
            return
        }
        
        guard let userId = AuthManager.shared.getUserId() else {
            AppLogger.error("Failed to get user ID from AuthManager")
            return
        }
        
        AppLogger.debug("Saving signature for user ID: \(userId)")
        
        let fileName = "signature_\(userId).png"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // Ensure the directory exists
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: nil)
            
            // Write the file
            try pngData.write(to: fileURL, options: .atomic)
            
            UserDefaults.standard.set(true, forKey: "signature_saved_\(userId)")  // flag indicating a saved signature
            signatureImage = UIImage(data: pngData)  // update state to show preview
            AppLogger.info("Signature saved successfully to local storage")
            
            // Upload to backend (async)
            Task.detached {
                do {
                    let response = try await APIService.shared.uploadUserSignature(imageData: pngData)
                    await MainActor.run {
                        AppLogger.info("Signature uploaded successfully to backend")
                        
                        // Store the signature URL for future PDF generation
                        if let signatureUrl = response.signatureUrl {
                            UserDefaults.standard.set(signatureUrl, forKey: "user_signature_url_\(userId)")
                            AppLogger.debug("Stored signature URL: \(signatureUrl)")
                        }
                    }
                } catch {
                    await MainActor.run {
                        AppLogger.error("Failed to upload signature to backend: \(error)")
                    }
                }
            }
        } catch {
            AppLogger.error("Error saving signature image to local storage: \(error)")
        }
    }
    

    
    private func generateAndShare() {
        Task {
            isGenerating = true
            do {
                // If a recipient is selected, send in-app instead of generating for share
                if let connection = selectedConnection,
                   let recipientUser = connection.connectedUser {
                    AppLogger.debug("Sending hand receipt to user ID: \(recipientUser.id)")
                    try await viewModel.sendHandReceipt(to: recipientUser.id)
                    isGenerating = false
                    // Show success alert (name already includes rank)
                    let name = recipientUser.name
                    let itemCount = viewModel.selectedPropertyIDs.count
                    let itemText = itemCount == 1 ? "item" : "items"
                    successMessage = "Hand Receipt sent to \(name)\n\n\(itemCount) \(itemText) transferred successfully\n\nA copy has been saved to your Documents inbox"
                    showSuccess = true
                } else {
                    // No recipient selected - generate PDF for sharing
                    AppLogger.debug("Generating PDF for share sheet")
                    generatedPDF = try await viewModel.generatePDF()
                    isGenerating = false
                    showingShareSheet = true
                }
            } catch {
                isGenerating = false
                AppLogger.error("Export failed: \(error)")
                
                // Provide more user-friendly error messages
                if let apiError = error as? APIService.APIError {
                    switch apiError {
                    case .serverError(_, let message):
                        errorMessage = message ?? "Server error occurred. Please try again or contact support."
                    case .badRequest(let message):
                        errorMessage = message ?? "Invalid request. Please check your selection and try again."
                    case .unauthorized:
                        errorMessage = "Authentication expired. Please log in again."
                    case .notFound:
                        errorMessage = "Recipient not found or no longer available."
                    default:
                        errorMessage = "Unable to send hand receipt. Please try again."
                    }
                } else {
                    errorMessage = "Network connection failed. Please check your internet connection and try again."
                }
                showError = true
            }
        }
    }
    

    
    private func sendHandReceiptInApp() async {
        guard let connection = selectedConnection,
              let recipientUser = connection.connectedUser else { return }
        isGenerating = true
        do {
            AppLogger.debug("Sending hand receipt in-app to user ID: \(recipientUser.id)")
            try await viewModel.sendHandReceipt(to: recipientUser.id)
            isGenerating = false
            // Show success alert (name already includes rank)
            let name = recipientUser.name
            let itemCount = viewModel.selectedPropertyIDs.count
            let itemText = itemCount == 1 ? "item" : "items"
            successMessage = "Hand Receipt sent to \(name)\n\n\(itemCount) \(itemText) transferred successfully\n\nA copy has been saved to your Documents inbox"
            showSuccess = true
            // Dismiss the picker after success
            showingRecipientPicker = false
        } catch {
            isGenerating = false
            AppLogger.error("In-app send failed: \(error)")
            
            // Provide more user-friendly error messages
            if let apiError = error as? APIService.APIError {
                switch apiError {
                case .serverError(_, let message):
                    errorMessage = message ?? "Server error occurred. Please try again or contact support."
                case .badRequest(let message):
                    errorMessage = message ?? "Invalid request. Please check your selection and try again."
                case .unauthorized:
                    errorMessage = "Authentication expired. Please log in again."
                case .notFound:
                    errorMessage = "Recipient not found or no longer available."
                default:
                    errorMessage = "Unable to send hand receipt. Please try again."
                }
            } else {
                errorMessage = "Network connection failed. Please check your internet connection and try again."
            }
            showError = true
        }
    }
}

// MARK: - Supporting Views

struct CompactEmptyState: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(AppColors.tertiaryText)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MinimalPropertySelectionRow: View {
    let property: Property
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Clean checkbox style
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(isSelected ? AppColors.primaryText : AppColors.tertiaryText)
                .onTapGesture {
                    onToggle()
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(property.name)
                    .font(AppFonts.bodyMedium)
                    .foregroundColor(AppColors.primaryText)
                
                HStack(spacing: 12) {
                    Text("SN: \(property.serialNumber)")
                        .font(AppFonts.monoCaption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    if let nsn = property.nsn {
                        Text("NSN: \(nsn)")
                            .font(AppFonts.monoCaption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            if property.isSensitive {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(AppColors.warning)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .background(isSelected ? AppColors.accentMuted : Color.clear)
        .cornerRadius(4)
    }
}

struct MinimalInfoRow: View {
    let label: String
    let value: String
    var valueFont: FontType = .sans
    
    enum FontType {
        case sans, mono, serif
    }
    
    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .kerning(AppFonts.wideKerning)
                .frame(width: 100, alignment: .leading)
            
            switch valueFont {
            case .sans:
                Text(value)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            case .mono:
                Text(value)
                    .font(AppFonts.monoBody)
                    .foregroundColor(AppColors.primaryText)
            case .serif:
                Text(value)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            }
            
            Spacer()
        }
    }
}

struct MinimalToggleRow: View {
    @Binding var isOn: Bool
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(AppColors.tertiaryText)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.bodyMedium)
                        .foregroundColor(AppColors.primaryText)
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .toggleStyle(MinimalToggleStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct MinimalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? AppColors.primaryText : AppColors.tertiaryBackground)
                    .frame(width: 48, height: 28)
                
                Circle()
                    .fill(AppColors.secondaryBackground)
                    .frame(width: 24, height: 24)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

struct MinimalLoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            AppColors.overlayBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryText))
                    .scaleEffect(0.8)
                
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.primaryText)
            }
            .padding(32)
            .background(AppColors.secondaryBackground)
            .cornerRadius(8)
            .shadow(color: AppColors.shadowColor, radius: 8, y: 4)
        }
    }
}

// MARK: - Share Components

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct UnitInfoEditorView: View {
    @Binding var unitInfo: DA2062ExportViewModel.UnitInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Unit Details")) {
                    TextField("Unit Name", text: $unitInfo.unitName)
                    TextField("DODAAC", text: $unitInfo.dodaac)
                    TextField("Stock Number", text: $unitInfo.stockNumber)
                    TextField("Location", text: $unitInfo.location)
                }
            }
            .navigationBarTitle("Edit Unit Info", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { dismiss() }
            )
        }
    }
} 