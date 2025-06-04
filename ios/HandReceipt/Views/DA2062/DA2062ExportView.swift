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
        .task {
            await viewModel.loadUserProperties()
            // Set pre-selected properties if any were passed in
            if !preSelectedPropertyIDs.isEmpty {
                viewModel.setInitialSelection(preSelectedPropertyIDs)
            }
        }
    }
    
    // MARK: - View Components
    
    private var unitInfoSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Unit Information",
                subtitle: "Organization details for this hand receipt",
                style: .serif,
                action: { /* Show unit info editor */ },
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
    
    private var exportOptionsSection: some View {
        VStack(spacing: 16) {
            ElegantSectionHeader(
                title: "Export Options",
                style: .uppercase
            )
            
            VStack(spacing: 0) {
                MinimalToggleRow(
                    isOn: $viewModel.groupByCategory,
                    icon: "folder",
                    title: "Group by Category",
                    subtitle: "Organize items by type"
                )
                
                Divider()
                    .background(AppColors.divider)
                    .padding(.leading, 44)
                
                MinimalToggleRow(
                    isOn: $viewModel.includeQRCodes,
                    icon: "qrcode",
                    title: "Include QR Codes",
                    subtitle: "Add QR codes for each item"
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
            .disabled(viewModel.selectedPropertyIDs.isEmpty)
            
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
            .disabled(viewModel.selectedPropertyIDs.isEmpty || !MFMailComposeViewController.canSendMail())
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
        }
    }
    
    // MARK: - Helper Methods
    
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