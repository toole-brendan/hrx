export interface DocumentSender {
    id: number;
    name: string;
    rank: string;
    unit: string;
}
export interface Document {
    id: number;
    type: 'maintenance_form' | 'transfer_document' | 'property_receipt' | 'other';
    subtype?: 'DA_2404' | 'DA_5988E' | string;
    title: string;
    description?: string;
    sender?: DocumentSender;
    recipient?: DocumentSender;
    sentAt: string;
    receivedAt?: string;
    status: 'unread' | 'read' | 'archived';
    formData: string;
    attachments?: string;
    box: 'inbox' | 'sent' | 'archive';
}
export declare const useDocumentService: () => {
    getDocuments: (box?: "inbox" | "sent" | "all", status?: string) => Promise<{
        documents: Document[];
        unread_count: number;
    }>;
    markAsRead: (documentId: number) => Promise<void>;
    archiveDocument: (documentId: number) => Promise<void>;
    deleteDocument: (documentId: number) => Promise<void>;
};
export declare function getDocuments(box?: 'inbox' | 'sent' | 'all', status?: string): Promise<{
    documents: Document[];
    unread_count: number;
}>;
export declare function markAsRead(documentId: number): Promise<void>;
export declare function archiveDocument(documentId: number): Promise<void>;
export declare function deleteDocument(documentId: number): Promise<void>;
export interface CreateMaintenanceFormRequest {
    propertyId: number;
    recipientUserId: number;
    formType: 'DA2404' | 'DA5988E';
    description: string;
    faultDescription?: string;
    attachments?: string[];
}
export interface DocumentsResponse {
    documents: Document[];
    count: number;
    unread_count: number;
}
export declare function getDocument(id: number): Promise<{
    document: Document;
}>;
export declare function sendMaintenanceForm(data: CreateMaintenanceFormRequest): Promise<{
    document: Document;
    message: string;
}>;
