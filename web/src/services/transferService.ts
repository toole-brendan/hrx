import { Transfer } from '@/types';

/**
 * Fetches all transfers from the API
 */
export async function fetchTransfers(): Promise<Transfer[]> {
  // TODO: Add authentication headers if required
  const response = await fetch('/api/transfers');
  if (!response.ok) {
    throw new Error('Failed to fetch transfers');
  }
  return response.json();
}

/**
 * Create a new transfer
 */
export async function createTransfer(newTransferData: Omit<Transfer, 'id' | 'date' | 'status'>): Promise<Transfer> {
  // TODO: Add authentication headers if required
  const response = await fetch('/api/transfers', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(newTransferData),
  });
  
  if (!response.ok) {
    throw new Error('Failed to create transfer');
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
  
  // TODO: Add authentication headers if required
  const response = await fetch(`/api/transfers/${id}/status`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ status, reason }),
  });
  
  if (!response.ok) {
    throw new Error(`Failed to ${status} transfer`);
  }
  
  return response.json();
}

/**
 * Get a single transfer by ID
 */
export async function getTransferById(id: string): Promise<Transfer> {
  // TODO: Add authentication headers if required
  const response = await fetch(`/api/transfers/${id}`);
  
  if (!response.ok) {
    throw new Error('Failed to fetch transfer');
  }
  
  return response.json();
}

/**
 * Delete a transfer (if permitted)
 */
export async function deleteTransfer(id: string): Promise<void> {
  // TODO: Add authentication headers if required
  const response = await fetch(`/api/transfers/${id}`, {
    method: 'DELETE',
  });
  
  if (!response.ok) {
    throw new Error('Failed to delete transfer');
  }
}

/**
 * Helper function to create authorization headers
 * (Can be used in the above functions if needed)
 */
function getAuthHeaders(): HeadersInit {
  // TODO: Get token from auth context or storage
  const token = localStorage.getItem('authToken');
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
} 