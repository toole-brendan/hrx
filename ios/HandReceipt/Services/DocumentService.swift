import Foundation

@MainActor
class DocumentService: ObservableObject {
    static let shared = DocumentService()
    
    @Published var documents: [Document] = []
    @Published var unreadCount: Int = 0
    @Published var unreadMaintenanceCount: Int = 0
    @Published var isLoading: Bool = false
    
    private init() {}
    
    // MARK: - Public Methods
    
    func loadDocuments() async {
        isLoading = true
        
        do {
            let response = try await APIService.shared.getDocuments()
            documents = response.documents
            unreadCount = response.unreadCount
            calculateUnreadMaintenanceCount()
        } catch {
            print("Failed to load documents: \(error)")
        }
        
        isLoading = false
    }
    
    func loadUnreadCount() async {
        do {
            let response = try await APIService.shared.getDocuments()
            unreadCount = response.unreadCount
            calculateUnreadMaintenanceCount()
        } catch {
            print("Failed to load unread count: \(error)")
        }
    }
    
    func markAsRead(_ document: Document) async {
        do {
            _ = try await APIService.shared.markDocumentAsRead(documentId: document.id)
            
            // Update local state
            if let index = documents.firstIndex(where: { $0.id == document.id }) {
                documents[index] = Document(
                    id: document.id,
                    type: document.type,
                    subtype: document.subtype,
                    title: document.title,
                    senderUserId: document.senderUserId,
                    recipientUserId: document.recipientUserId,
                    propertyId: document.propertyId,
                    formData: document.formData,
                    description: document.description,
                    attachments: document.attachments,
                    status: .read,
                    sentAt: document.sentAt,
                    readAt: Date(),
                    createdAt: document.createdAt,
                    updatedAt: Date()
                )
            }
            
            // Update counts
            if document.isUnread {
                unreadCount = max(0, unreadCount - 1)
                if document.type == DocumentType.maintenanceForm.rawValue {
                    unreadMaintenanceCount = max(0, unreadMaintenanceCount - 1)
                }
            }
        } catch {
            print("Failed to mark document as read: \(error)")
        }
    }
    
    func sendMaintenanceForm(_ request: CreateMaintenanceFormRequest) async throws -> SendMaintenanceFormResponse {
        return try await APIService.shared.sendMaintenanceForm(request)
    }
    
    func refreshDocuments() async {
        await loadDocuments()
    }
    
    // MARK: - Private Methods
    
    private func calculateUnreadMaintenanceCount() {
        unreadMaintenanceCount = documents.filter { 
            $0.isUnread && $0.type == DocumentType.maintenanceForm.rawValue 
        }.count
    }
}

 