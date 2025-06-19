const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';

// Document types
export interface Document {
  id: number;
  type: string;
  subtype?: string;
  title: string;
  senderUserId: number;
  recipientUserId: number;
  propertyId?: number;
  formData: string;
  description?: string;
  attachments?: string;
  status: 'unread' | 'read' | 'archived';
  sentAt: string;
  readAt?: string;
  createdAt: string;
  updatedAt: string;
  
  // Relationships
  sender?: {
    id: number;
    name: string;
    rank?: string;
    unit?: string;
  };
  recipient?: {
    id: number;
    name: string;
    rank?: string;
    unit?: string;
  };
  property?: {
    id: number;
    name: string;
    serialNumber: string;
    nsn?: string;
  };
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

export async function getDocuments(
  box?: 'inbox' | 'sent' | 'all',
  status?: string,
  type?: string
): Promise<DocumentsResponse> {
  const params = new URLSearchParams();
  if (box) params.append('box', box);
  if (status) params.append('status', status);
  if (type) params.append('type', type);

  const response = await fetch(`${API_BASE_URL}/documents?${params}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to fetch documents');
  return response.json();
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

export async function markAsRead(id: number): Promise<{ message: string }> {
  const response = await fetch(`${API_BASE_URL}/documents/${id}/read`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to mark document as read');
  return response.json();
} 