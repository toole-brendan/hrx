import { useAuth } from '@/contexts/AuthContext';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

// Document types
export interface DocumentSender {
  id: number;
  name: string;
  rank: string;
  unit: string;
}

export interface Document {
  id: number;
  type: 'transfer_document' | 'property_receipt' | 'message' | 'other';
  subtype?: string;
  title: string;
  description?: string;
  sender?: DocumentSender;
  recipient?: DocumentSender;
  sentAt: string;
  receivedAt?: string;
  status: 'unread' | 'read' | 'archived';
  formData: string; // JSON string of form-specific data
  attachments?: string; // JSON string of attachment URLs
  box: 'inbox' | 'sent' | 'archive';
}

export interface CreateDocumentInput {
  type: string;
  subtype?: string;
  title: string;
  recipientUserId: number;
  formData: any;
  description?: string;
  attachments?: string[];
}

// For use in React components with hooks
export const useDocumentService = () => {
  const { authedFetch } = useAuth();

  const getDocuments = async (box: 'inbox' | 'sent' | 'all' = 'inbox', status?: string): Promise<{ documents: Document[]; unread_count: number }> => {
    const params = new URLSearchParams({ box });
    if (status) params.append('status', status);
    
    const { data } = await authedFetch<{ documents: Document[]; unread_count: number }>(`/api/documents?${params}`);
    return data;
  };

  const markAsRead = async (documentId: number): Promise<void> => {
    await authedFetch(`/api/documents/${documentId}/read`, {
      method: 'PATCH'
    });
  };

  const archiveDocument = async (documentId: number): Promise<void> => {
    await authedFetch(`/api/documents/${documentId}/archive`, {
      method: 'PATCH'
    });
  };

  const deleteDocument = async (documentId: number): Promise<void> => {
    await authedFetch(`/api/documents/${documentId}`, {
      method: 'DELETE'
    });
  };

  const createDocument = async (input: CreateDocumentInput): Promise<{ document: Document; message: string }> => {
    const { data } = await authedFetch<{ document: Document; message: string }>('/api/documents', {
      method: 'POST',
      body: JSON.stringify({
        type: input.type,
        subtype: input.subtype,
        title: input.title,
        recipientUserId: input.recipientUserId,
        formData: JSON.stringify(input.formData),
        description: input.description,
        attachments: input.attachments ? JSON.stringify(input.attachments) : undefined
      })
    });
    return data;
  };

  return {
    getDocuments,
    markAsRead,
    archiveDocument,
    deleteDocument,
    createDocument
  };
};

// For backward compatibility - these functions use regular fetch
// and should be replaced with the hook version in components
export async function getDocuments(box: 'inbox' | 'sent' | 'all' = 'inbox', status?: string): Promise<{ documents: Document[]; unread_count: number }> {
  const params = new URLSearchParams({ box });
  if (status) params.append('status', status);
  
  const response = await fetch(`${API_BASE_URL}/documents?${params}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include'
  });

  if (!response.ok) {
    throw new Error('Failed to fetch documents');
  }

  const text = await response.text();
  if (!text) {
    // Return empty result if no content
    return { documents: [], unread_count: 0 };
  }
  
  try {
    return JSON.parse(text);
  } catch (e) {
    console.error('Failed to parse documents response:', text);
    throw new Error('Invalid response from server');
  }
}

export async function markAsRead(documentId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/documents/${documentId}/read`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include'
  });

  if (!response.ok) {
    throw new Error('Failed to mark document as read');
  }
}

export async function archiveDocument(documentId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/documents/${documentId}/archive`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include'
  });

  if (!response.ok) {
    throw new Error('Failed to archive document');
  }
}

export async function deleteDocument(documentId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/documents/${documentId}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include'
  });

  if (!response.ok) {
    throw new Error('Failed to delete document');
  }
}

export interface DocumentsResponse {
  documents: Document[];
  count: number;
  unread_count: number;
}

export async function getDocument(id: number): Promise<{ document: Document }> {
  const response = await fetch(`${API_BASE_URL}/documents/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to fetch document');
  return response.json();
}

export async function searchDocuments(query: string): Promise<{ documents: Document[]; count: number }> {
  const response = await fetch(`${API_BASE_URL}/documents/search?q=${encodeURIComponent(query)}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to search documents');
  
  const text = await response.text();
  if (!text) {
    // Return empty result if no content
    return { documents: [], count: 0 };
  }
  
  try {
    return JSON.parse(text);
  } catch (e) {
    console.error('Failed to parse search response:', text);
    throw new Error('Invalid response from server');
  }
}

export type BulkOperation = 'read' | 'archive' | 'delete';

export async function bulkUpdateDocuments(
  documentIds: number[], 
  operation: BulkOperation
): Promise<{ successCount: number; failedCount: number; message: string }> {
  const response = await fetch(`${API_BASE_URL}/documents/bulk`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
    body: JSON.stringify({ documentIds, operation })
  });

  if (!response.ok) throw new Error('Failed to perform bulk operation');
  return response.json();
}

export interface UploadDocumentData {
  file: File;
  title: string;
  type?: string;
  description?: string;
}

export async function uploadDocument(data: UploadDocumentData): Promise<{ document: Document; message: string }> {
  const formData = new FormData();
  formData.append('file', data.file);
  formData.append('title', data.title);
  if (data.type) formData.append('type', data.type);
  if (data.description) formData.append('description', data.description);
  
  const response = await fetch(`${API_BASE_URL}/documents/upload`, {
    method: 'POST',
    credentials: 'include',
    body: formData
  });

  if (!response.ok) throw new Error('Failed to upload document');
  return response.json();
}

export async function createDocument(input: CreateDocumentInput): Promise<{ document: Document; message: string }> {
  const response = await fetch(`${API_BASE_URL}/documents`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
    body: JSON.stringify({
      type: input.type,
      subtype: input.subtype,
      title: input.title,
      recipientUserId: input.recipientUserId,
      formData: JSON.stringify(input.formData),
      description: input.description,
      attachments: input.attachments ? JSON.stringify(input.attachments) : undefined
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(error || 'Failed to create document');
  }
  
  return response.json();
}
 