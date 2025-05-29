import { Transfer } from '@/types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';

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
  return data.transfers || data || []; // Handle both {transfers: [...]} and direct array response
}

/**
 * Create a new transfer
 */
export async function createTransfer(newTransferData: Omit<Transfer, 'id' | 'date' | 'status'>): Promise<Transfer> {
  const response = await fetch(`${API_BASE_URL}/transfers`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify(newTransferData),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create transfer: ${error}`);
  }
  
  return response.json();
}

/**
 * Update the status of a transfer (approve/reject)
 */
export async function updateTransferStatus(params: { 
  id: string; 
  status: 'approved' | 'rejected'; 
  reason?: string;
}): Promise<Transfer> {
  const { id, status, reason } = params;
  
  const response = await fetch(`${API_BASE_URL}/transfers/${id}/status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ status, reason }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to ${status} transfer: ${error}`);
  }
  
  return response.json();
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
  
  return response.json();
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