import { Transfer, BackendTransfer, TransferOffer, OfferResponse } from '@/types';

// Transfer Service API
const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

/**
 * Get authentication headers
 */
function getAuthHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    // Cookie-based auth is handled automatically by fetch with credentials
  };
}

/**
 * Maps backend transfer format to frontend Transfer format
 */
function mapBackendTransferToFrontend(backendTransfer: BackendTransfer): Transfer {
  return {
    id: backendTransfer.id.toString(),
    name: backendTransfer.property?.name || backendTransfer.item_name || 'Unknown Item',
    serialNumber: backendTransfer.property?.serial_number || backendTransfer.serial_number || '',
    from: backendTransfer.from_user?.name || backendTransfer.from || 'Unknown',
    to: backendTransfer.to_user?.name || backendTransfer.to || 'Unknown',
    date: backendTransfer.request_date || new Date().toISOString(),
    status: (backendTransfer.status?.toLowerCase() || 'pending') as 'approved' | 'rejected' | 'pending',
    approvedDate: backendTransfer.resolved_date && backendTransfer.status === 'Approved' 
      ? backendTransfer.resolved_date 
      : undefined,
    rejectedDate: backendTransfer.resolved_date && backendTransfer.status === 'Rejected' 
      ? backendTransfer.resolved_date 
      : undefined,
    rejectionReason: backendTransfer.status === 'Rejected' && backendTransfer.notes 
      ? backendTransfer.notes 
      : undefined,
  };
}

/**
 * Fetches all transfers from the API
 */
export async function fetchTransfers(): Promise<Transfer[]> {
  const response = await fetch(`${API_BASE_URL}/transfers`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include', // Include cookies for session auth
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch transfers: ${response.statusText}`);
  }
  
  const data = await response.json();
  const transfers = data.transfers || data || [];
  return transfers.map(mapBackendTransferToFrontend);
}

/**
 * Create a new transfer
 */
export async function createTransfer(transferData: {
  propertyId: number;
  toUserId: number;
  includeComponents?: boolean;
  notes?: string;
}): Promise<Transfer> {
  const response = await fetch(`${API_BASE_URL}/transfers`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({
      propertyId: transferData.propertyId,
      toUserId: transferData.toUserId,
      includeComponents: transferData.includeComponents || false,
      notes: transferData.notes,
    }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create transfer: ${error}`);
  }
  
  const backendTransfer = await response.json();
  return mapBackendTransferToFrontend(backendTransfer);
}

/**
 * Update the status of a transfer (approve/reject)
 */
export async function updateTransferStatus(params: {
  id: string;
  status: 'approved' | 'rejected';
  notes?: string;
}): Promise<Transfer> {
  const { id, status, notes } = params;
  
  // Map frontend status to backend format
  const backendStatus = status === 'approved' ? 'Approved' : 'Rejected';
  
  const response = await fetch(`${API_BASE_URL}/transfers/${id}/status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ status: backendStatus, notes: notes }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to ${status} transfer: ${error}`);
  }
  
  const backendTransfer = await response.json();
  return mapBackendTransferToFrontend(backendTransfer);
}

/**
 * Get a single transfer by ID
 */
export async function getTransferById(id: string): Promise<Transfer> {
  const response = await fetch(`${API_BASE_URL}/transfers/${id}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch transfer: ${response.statusText}`);
  }
  
  const data = await response.json();
  const backendTransfer = data.transfer || data;
  return mapBackendTransferToFrontend(backendTransfer);
}

/**
 * Delete a transfer (if permitted)
 */
export async function deleteTransfer(id: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/transfers/${id}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to delete transfer: ${response.statusText}`);
  }
}

/**
 * Request a transfer by serial number
 */
export async function requestBySerial(data: {
  serialNumber: string;
  includeComponents?: boolean;
  notes?: string;
}): Promise<Transfer> {
  const response = await fetch(`${API_BASE_URL}/transfers/request-by-serial`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({
      serialNumber: data.serialNumber,
      includeComponents: data.includeComponents || false,
      notes: data.notes,
    }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to request transfer: ${error}`);
  }
  
  const backendTransfer = await response.json();
  return mapBackendTransferToFrontend(backendTransfer);
}

/**
 * Create an offer to transfer property
 */
export async function createOffer(data: {
  propertyId: number;
  recipientIds: number[];
  includeComponents?: boolean;
  notes?: string;
  expiresInDays?: number;
}): Promise<OfferResponse> {
  const response = await fetch(`${API_BASE_URL}/transfers/offer`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({
      propertyId: data.propertyId,
      recipientIds: data.recipientIds,
      includeComponents: data.includeComponents || false,
      notes: data.notes,
      expiresInDays: data.expiresInDays,
    }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create offer: ${error}`);
  }
  
  return response.json();
}

/**
 * Get active offers for the current user
 */
export async function getActiveOffers(): Promise<TransferOffer[]> {
  const response = await fetch(`${API_BASE_URL}/transfers/offers/active`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to fetch offers: ${response.statusText}`);
  }
  
  const data = await response.json();
  return data.offers || [];
}

/**
 * Accept a transfer offer
 */
export async function acceptOffer(offerId: number): Promise<BackendTransfer> {
  const response = await fetch(`${API_BASE_URL}/transfers/offers/${offerId}/accept`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to accept offer: ${error}`);
  }
  
  return response.json();
} 