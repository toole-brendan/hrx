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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Unit Information Card
                        unitInfoCard
                        
                        // Property Selection Card
                        propertySelectionCard
                        
                        // Export Options Card
                        exportOptionsCard
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
                
                if isGenerating {
                    LoadingOverlay(message: "Generating DA 2062...")
                }
            }
            .navigationTitle("Export DA 2062")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
            }
        }
    }
    
    // MARK: - View Components
    
    private var unitInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
                Text("Unit Information")
                    .font(.headline)
                Spacer()
                Button("Edit") {
                    // Show unit info editor
                }
                .font(.caption)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Unit", value: viewModel.unitInfo.unitName)
                InfoRow(label: "DODAAC", value: viewModel.unitInfo.dodaac)
                InfoRow(label: "Location", value: viewModel.unitInfo.location)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var propertySelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.green)
                Text("Select Properties")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.selectedPropertyIDs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if viewModel.properties.isEmpty {
                Text("No properties available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                VStack(spacing: 8) {
                    // Quick actions
                    HStack(spacing: 12) {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        .font(.caption)
                        
                        Button("Clear") {
                            viewModel.clearSelection()
                        }
                        .font(.caption)
                        
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
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.caption)
                        }
                    }
                    
                    // Property list
                    ForEach(viewModel.properties) { property in
                        PropertySelectionRow(
                            property: property,
                            isSelected: viewModel.selectedPropertyIDs.contains(property.id),
                            onToggle: {
                                viewModel.toggleSelection(for: property.id)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var exportOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.orange)
                Text("Export Options")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 12) {
                Toggle(isOn: $viewModel.groupByCategory) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading) {
                            Text("Group by Category")
                            Text("Organize items by type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Toggle(isOn: $viewModel.includeQRCodes) {
                    HStack {
                        Image(systemName: "qrcode")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading) {
                            Text("Include QR Codes")
                            Text("Add QR codes for each item")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: generateAndShare) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Generate & Share")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.selectedPropertyIDs.isEmpty)
            
            Button(action: {
                showingRecipientInput = true
            }) {
                HStack {
                    Image(systemName: "envelope")
                    Text("Email PDF")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.selectedPropertyIDs.isEmpty ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
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
                // Generate PDF and show mail composer
                generatedPDF = try await viewModel.generatePDF()
                isGenerating = false
                showingMailComposer = true
            } else {
                // Send directly via backend
                let recipients = emailRecipients
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                try await viewModel.emailPDF(to: recipients)
                isGenerating = false
                
                // Show success
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

struct PropertySelectionRow: View {
    let property: Property
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
                .onTapGesture {
                    onToggle()
                }
            
            VStack(alignment: .leading) {
                Text(property.name)
                    .font(.subheadline)
                HStack {
                    Text("SN: \(property.serialNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let nsn = property.nsn {
                        Text("• NSN: \(nsn)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if property.isSensitive {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// InfoRow is imported from DocumentsView

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
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