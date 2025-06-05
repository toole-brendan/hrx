import SwiftUI
import MessageUI

struct DA2062ExportView: View {
    @StateObject private var viewModel = DA2062ExportViewModel()
    @State private var showingMailComposer = false
    @State private var showingShareSheet = false
    @State private var showingRecipientInput = false
    @State private var emailRecipients = ""
    @State private var generatedPDF: Data?
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
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
        .navigationBarHidden(true)
        .sheet(isPresented: $showingMailComposer) {
            if let pdfData = generatedPDF {
                MailComposerView(
                    subject: "DA Form 2062 - \(viewModel.formNumber)",
                    body: generateEmailBody(),
                    recipients: emailRecipients.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    attachments: [(data: pdfData, mimeType: "application/pdf", fileName: "DA2062_\(viewModel.formNumber).pdf")]
                )
            }
        }
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
        .sheet(isPresented: $showingUnitInfoEditor) {
            UnitInfoEditorView(unitInfo: $viewModel.unitInfo)
        }
        .sheet(isPresented: $showingSignatureCapture) {
            SignatureCaptureView { image in 
                print("DEBUG: SignatureCaptureView onSave callback called")
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
                    Image(uiImage: sigImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        .shadow(color: AppColors.shadowColor.opacity(0.1), radius: 2, y: 1)
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
                
                Divider()
                    .padding(.horizontal, 16)
                
                MinimalToggleRow(
                    isOn: $viewModel.groupByCategory,
                    icon: "folder",
                    title: "Group by Category",
                    subtitle: "Organize items by type"
                )
            }
            .cleanCard(padding: 0)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: generateAndShare) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .regular))
                    Text("Generate & Share")
                        .font(AppFonts.bodyMedium)
                }
            }
            .buttonStyle(.minimalPrimary)
            .disabled(viewModel.selectedPropertyIDs.isEmpty || selectedConnection == nil || signatureImage == nil)
            
            Button(action: {
                showingRecipientInput = true
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .font(.system(size: 16, weight: .regular))
                    Text("Email PDF")
                        .font(AppFonts.bodyMedium)
                }
            }
            .buttonStyle(.minimalSecondary)
            .disabled(viewModel.selectedPropertyIDs.isEmpty || !MFMailComposeViewController.canSendMail() || selectedConnection == nil || signatureImage == nil)
            .alert("Email Recipients", isPresented: $showingRecipientInput) {
                TextField("Enter email addresses", text: $emailRecipients)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Send") {
                    Task {
                        await generateAndEmail()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter recipient email addresses separated by commas")
            }
            
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
            print("DEBUG: Failed to get user ID when loading signature")
            return
        }
        
        print("DEBUG: Loading signature for user ID: \(userId)")
        
        let fileName = "signature_\(userId).png"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        print("DEBUG: Documents directory: \(documentsPath.path)")
        print("DEBUG: Looking for signature at: \(fileURL.path)")
        
        // List all files in documents directory for debugging
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: documentsPath.path)
            print("DEBUG: Files in documents directory: \(files)")
        } catch {
            print("DEBUG: Could not list documents directory: \(error)")
        }
        
        // Check UserDefaults flag
        let hasSavedFlag = UserDefaults.standard.bool(forKey: "signature_saved_\(userId)")
        print("DEBUG: UserDefaults signature_saved flag: \(hasSavedFlag)")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            print("DEBUG: Signature file exists")
            
            // Get file attributes
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int ?? 0
                let modificationDate = attributes[.modificationDate] as? Date
                print("DEBUG: File size: \(fileSize) bytes")
                print("DEBUG: File modification date: \(modificationDate?.description ?? "unknown")")
            } catch {
                print("DEBUG: Could not get file attributes: \(error)")
            }
            
            if let imageData = try? Data(contentsOf: fileURL) {
                print("DEBUG: Successfully loaded signature data, size: \(imageData.count) bytes")
                if let image = UIImage(data: imageData) {
                    print("DEBUG: Successfully created UIImage from data, size: \(image.size)")
                    signatureImage = image
                    print("DEBUG: Signature loaded and UI state updated")
                } else {
                    print("DEBUG: Failed to create UIImage from signature data")
                }
            } else {
                print("DEBUG: Failed to read signature data from file")
            }
        } else {
            print("DEBUG: Signature file does not exist")
            // Clear the UserDefaults flag if file doesn't exist
            if hasSavedFlag {
                print("DEBUG: Clearing UserDefaults flag since file doesn't exist")
                UserDefaults.standard.set(false, forKey: "signature_saved_\(userId)")
            }
        }
    }
    
    private func saveSignatureImage(_ image: UIImage) {
        print("DEBUG: saveSignatureImage called with image size: \(image.size)")
        print("DEBUG: Image scale: \(image.scale)")
        print("DEBUG: Image description: \(image)")
        
        guard let pngData = image.pngData() else {
            print("DEBUG: Failed to convert image to PNG data")
            return
        }
        
        guard let userId = AuthManager.shared.getUserId() else {
            print("DEBUG: Failed to get user ID from AuthManager")
            return
        }
        
        print("DEBUG: Saving signature for user ID: \(userId)")
        print("DEBUG: PNG data size: \(pngData.count) bytes")
        
        let fileName = "signature_\(userId).png"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        print("DEBUG: Documents directory: \(documentsPath.path)")
        print("DEBUG: Saving signature to: \(fileURL.path)")
        
        // Check if directory exists and is writable
        let documentsDir = documentsPath.path
        let isWritable = FileManager.default.isWritableFile(atPath: documentsDir)
        print("DEBUG: Documents directory writable: \(isWritable)")
        
        do {
            // Ensure the directory exists
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: nil)
            
            // Write the file
            try pngData.write(to: fileURL, options: .atomic)
            
            // Verify the file was written
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            print("DEBUG: File exists after write: \(fileExists)")
            
            if fileExists {
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
                print("DEBUG: Written file size: \(fileSize) bytes")
            }
            
            UserDefaults.standard.set(true, forKey: "signature_saved_\(userId)")  // flag indicating a saved signature
            signatureImage = UIImage(data: pngData)  // update state to show preview
            print("DEBUG: Signature saved successfully to local storage and UI state updated")
            
            // Upload to backend (async)
            Task.detached {
                do {
                    let response = try await APIService.shared.uploadUserSignature(imageData: pngData)
                    await MainActor.run {
                        print("DEBUG: Signature uploaded successfully to backend: \(response.message)")
                        
                        // Store the signature URL for future PDF generation
                        if let signatureUrl = response.signatureUrl {
                            UserDefaults.standard.set(signatureUrl, forKey: "user_signature_url_\(userId)")
                            print("DEBUG: Stored signature URL: \(signatureUrl)")
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("DEBUG: Failed to upload signature to backend: \(error)")
                    }
                }
            }
        } catch {
            print("DEBUG: Error saving signature image to local storage: \(error)")
            print("DEBUG: Error details: \(error.localizedDescription)")
        }
    }
    
    private func generateEmailBody() -> String {
        """
        Please find attached the DA Form 2062 Hand Receipt.
        
        Form Number: \(viewModel.formNumber)
        Date: \(Date().formatted())
        Items: \(viewModel.selectedPropertyIDs.count)
        
        This document was generated electronically via HandReceipt.
        """
    }
    
    private func generateAndShare() {
        Task {
            isGenerating = true
            do {
                generatedPDF = try await viewModel.generatePDF()
                isGenerating = false
                showingShareSheet = true
            } catch {
                isGenerating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func generateAndEmail() async {
        isGenerating = true
        do {
            if emailRecipients.isEmpty {
                generatedPDF = try await viewModel.generatePDF()
                isGenerating = false
                showingMailComposer = true
            } else {
                let recipients = emailRecipients
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                try await viewModel.emailPDF(to: recipients)
                isGenerating = false
                
                errorMessage = "DA 2062 sent successfully to \(recipients.count) recipient(s)"
                showError = true
            }
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func sendHandReceiptInApp() async {
        guard let connection = selectedConnection,
              let recipientUser = connection.connectedUser else { return }
        isGenerating = true
        do {
            try await viewModel.sendHandReceipt(to: recipientUser.id)
            isGenerating = false
            // Show success alert
            let rank = recipientUser.rank ?? ""
            errorMessage = "Hand Receipt sent to \(rank) \(recipientUser.name)"
            showError = true
            // Dismiss the picker and export view after success
            showingRecipientPicker = false
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
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

// MARK: - Mail and Share Components

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]
    let attachments: [(data: Data, mimeType: String, fileName: String)]
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        
        for attachment in attachments {
            composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

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