import SwiftUI

struct DocumentsView: View {
    @StateObject private var documentService = DocumentService.shared
    @State private var selectedFilter: DocumentFilter = .all
    @State private var selectedDocument: Document?
    @State private var showingDocumentDetail = false
    
    enum DocumentFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case maintenance = "Maintenance"
        case archived = "Archived"
        
        var icon: String {
            switch self {
            case .all: return "tray"
            case .unread: return "circle.fill"
            case .maintenance: return "wrench.and.screwdriver"
            case .archived: return "archivebox"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer for header
                    Color.clear
                        .frame(height: 36)
                    
                    // Filter tabs
                    filterTabs
                    
                    // Documents list
                    documentsSection
                    
                    // Bottom spacer
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(AppColors.appBackground.ignoresSafeArea(.all))
            .refreshable {
                await documentService.refreshDocuments()
            }
            
            // Header
            UniversalHeaderView(title: "Documents")
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await documentService.loadDocuments()
        }
        .sheet(isPresented: $showingDocumentDetail) {
            if let document = selectedDocument {
                DocumentDetailView(document: document) {
                    await documentService.markAsRead(document)
                }
            }
        }
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DocumentFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        HStack(spacing: 8) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 14, weight: .medium))
                            
                            Text(filter.rawValue)
                                .font(AppFonts.caption)
                                .fontWeight(.medium)
                            
                            if filter == .unread && documentService.unreadCount > 0 {
                                Text("\(documentService.unreadCount)")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilter == filter ? AppColors.accent : AppColors.secondaryBackground
                        )
                        .foregroundColor(
                            selectedFilter == filter ? .white : AppColors.primaryText
                        )
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
    }
    
    private var documentsSection: some View {
        LazyVStack(spacing: 0) {
            if documentService.isLoading && documentService.documents.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading documents...")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if filteredDocuments.isEmpty {
                // Empty state
                DocumentsEmptyState(filter: selectedFilter)
                    .padding(.top, 60)
            } else {
                // Documents list
                ForEach(filteredDocuments, id: \.id) { document in
                    DocumentRowView(document: document) {
                        selectedDocument = document
                        showingDocumentDetail = true
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var filteredDocuments: [Document] {
        switch selectedFilter {
        case .all:
            return documentService.documents
        case .unread:
            return documentService.documents.filter { $0.isUnread }
        case .maintenance:
            return documentService.documents.filter { 
                $0.type == Document.DocumentType.maintenanceForm.rawValue 
            }
        case .archived:
            return documentService.documents.filter { $0.status == .archived }
        }
    }
}

// MARK: - Supporting Views

struct DocumentRowView: View {
    let document: Document
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            WebAlignedCard {
                HStack(spacing: 16) {
                    // Document type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(documentTypeColor.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: documentTypeIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(documentTypeColor)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(document.title)
                                .font(document.isUnread ? AppFonts.bodyBold : AppFonts.body)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(document.shortFormattedSentDate)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        
                        if let description = document.description {
                            Text(description)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(2)
                        }
                        
                        // Sender info
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.tertiaryText)
                            
                            Text("From: \(document.sender?.name ?? "Unknown")")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                            
                            Spacer()
                            
                            if document.isUnread {
                                Circle()
                                    .fill(AppColors.accent)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var documentTypeIcon: String {
        switch document.type {
        case Document.DocumentType.maintenanceForm.rawValue:
            return "wrench.and.screwdriver"
        case Document.DocumentType.transferForm.rawValue:
            return "arrow.triangle.2.circlepath"
        default:
            return "doc.text"
        }
    }
    
    private var documentTypeColor: Color {
        switch document.type {
        case Document.DocumentType.maintenanceForm.rawValue:
            return .orange
        case Document.DocumentType.transferForm.rawValue:
            return .blue
        default:
            return AppColors.accent
        }
    }
}

struct DocumentsEmptyState: View {
    let filter: DocumentsView.DocumentFilter
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.tertiaryText.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppColors.tertiaryText)
            }
            
            // Message
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(AppFonts.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(emptyStateMessage)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .padding()
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all: return "tray"
        case .unread: return "checkmark.circle"
        case .maintenance: return "wrench.and.screwdriver"
        case .archived: return "archivebox"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Documents"
        case .unread: return "All Caught Up!"
        case .maintenance: return "No Maintenance Forms"
        case .archived: return "No Archived Documents"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "You haven't received any documents yet. Maintenance forms and other documents will appear here."
        case .unread: return "You've read all your documents. New documents will appear here when you receive them."
        case .maintenance: return "You haven't received any maintenance forms yet. Forms sent to you will appear here."
        case .archived: return "You don't have any archived documents. Documents you archive will appear here."
        }
    }
}

// MARK: - Document Detail View

struct DocumentDetailView: View {
    let document: Document
    let onMarkAsRead: () async -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Document header
                    documentHeader
                    
                    // Content based on document type
                    if document.type == Document.DocumentType.maintenanceForm.rawValue {
                        maintenanceFormContent
                    } else {
                        genericDocumentContent
                    }
                }
                .padding()
            }
            .background(AppColors.appBackground)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if document.isUnread {
                        Button("Mark Read") {
                            Task {
                                await onMarkAsRead()
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .task {
            if document.isUnread {
                await onMarkAsRead()
            }
        }
    }
    
    private var documentHeader: some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Document Information")
                        .font(AppFonts.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    if document.isUnread {
                        Text("Unread")
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accent)
                            .cornerRadius(12)
                    }
                }
                
                VStack(spacing: 12) {
                    InfoRow(label: "From", value: document.sender?.name ?? "Unknown")
                    InfoRow(label: "Sent", value: document.formattedSentDate)
                    InfoRow(label: "Type", value: Document.DocumentType(rawValue: document.type)?.displayName ?? document.type)
                    
                    if let description = document.description {
                        InfoRow(label: "Description", value: description)
                    }
                }
            }
            .padding()
        }
    }
    
    private var maintenanceFormContent: some View {
        Group {
            if let formData = document.formDataDecoded {
                WebAlignedCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Maintenance Form Details")
                            .font(AppFonts.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryText)
                        
                        VStack(spacing: 12) {
                            InfoRow(label: "Form Type", value: formData.formType.displayName)
                            InfoRow(label: "Equipment", value: formData.equipmentName)
                            InfoRow(label: "Serial Number", value: formData.serialNumber)
                            InfoRow(label: "NSN", value: formData.nsn)
                            InfoRow(label: "Location", value: formData.location)
                            InfoRow(label: "Problem Description", value: formData.description)
                            
                            if !formData.faultDescription.isEmpty {
                                InfoRow(label: "Fault Description", value: formData.faultDescription)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var genericDocumentContent: some View {
        WebAlignedCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Document Content")
                    .font(AppFonts.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primaryText)
                
                Text(document.formData)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(AppFonts.caption)
                .foregroundColor(AppColors.tertiaryText)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct DocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DocumentsView()
        }
        .preferredColorScheme(.dark)
    }
} 