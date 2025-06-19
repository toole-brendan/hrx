import { useAuth } from '@/contexts/AuthContext';

const API_BASE_URL = import.meta.env.DEV 
  ? '/api'  // Use relative path in development to go through Vite proxy
  : (import.meta.env.VITE_API_URL || 'http://localhost:8000/api');

// Document types
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
  formData: string; // JSON string of form-specific data
  attachments?: string; // JSON string of attachment URLs
  box: 'inbox' | 'sent' | 'archive';
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

  return {
    getDocuments,
    markAsRead,
    archiveDocument,
    deleteDocument
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

  return response.json();
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

export async function sendMaintenanceForm(
  data: CreateMaintenanceFormRequest
): Promise<{ document: Document; message: string }> {
  const response = await fetch(`${API_BASE_URL}/documents/maintenance-form`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
    body: JSON.stringify(data),
  });

  if (!response.ok) throw new Error('Failed to send maintenance form');
  return response.json();
} 