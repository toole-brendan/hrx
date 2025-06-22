const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

export interface UserConnection {
  id: number;
  userId: number;
  connectedUserId: number;
  connectionStatus: 'pending' | 'accepted' | 'blocked';
  connectedUser?: {
    id: number;
    name: string;
    rank: string;
    unit: string;
    phone?: string;
  };
  createdAt: string;
}

export interface SearchUserResult {
  id: number;
  name: string;
  rank: string;
  unit: string;
  email: string;
}

export async function getConnections(): Promise<UserConnection[]> {
  const response = await fetch(`${API_BASE_URL}/users/connections`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to fetch connections');
  
  const data = await response.json();
  return data.connections || [];
}

export interface SearchFilters {
  organization?: string;
  rank?: string;
  location?: string;
}

export async function searchUsers(query: string, filters?: SearchFilters): Promise<SearchUserResult[]> {
  const params = new URLSearchParams();
  params.append('q', query);
  
  if (filters?.organization) {
    params.append('organization', filters.organization);
  }
  if (filters?.rank) {
    params.append('rank', filters.rank);
  }
  if (filters?.location) {
    params.append('location', filters.location);
  }
  
  const response = await fetch(`${API_BASE_URL}/users/search?${params.toString()}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
  });

  if (!response.ok) throw new Error('Failed to search users');
  
  const data = await response.json();
  return data.users || [];
}

export async function sendConnectionRequest(targetUserId: number): Promise<UserConnection> {
  const response = await fetch(`${API_BASE_URL}/users/connections`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
    body: JSON.stringify({ targetUserId }),
  });

  if (!response.ok) throw new Error('Failed to send connection request');
  
  return response.json();
}

export async function updateConnectionStatus(
  connectionId: number,
  status: 'accepted' | 'blocked'
): Promise<UserConnection> {
  const response = await fetch(`${API_BASE_URL}/users/connections/${connectionId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include',
    body: JSON.stringify({ status }),
  });

  if (!response.ok) throw new Error('Failed to update connection');
  
  return response.json();
}

export async function exportConnections(): Promise<void> {
  const url = `${API_BASE_URL}/users/connections/export`;
  console.log('Attempting to export from:', url);
  
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Accept': 'text/csv, application/octet-stream, */*'
    },
    credentials: 'include',
  });

  if (!response.ok) {
    let errorMessage = `${response.status} ${response.statusText}`;
    try {
      const errorText = await response.text();
      console.error('Export failed:', response.status, errorText);
      if (errorText) {
        errorMessage += `: ${errorText}`;
      }
    } catch (e) {
      console.error('Could not read error response:', e);
    }
    throw new Error(`Failed to export connections: ${errorMessage}`);
  }
  
  // Get the filename from the Content-Disposition header or use a default
  const contentDisposition = response.headers.get('Content-Disposition');
  const filename = contentDisposition?.match(/filename="(.+)"/)?.[1] || 'connections.csv';
  
  // Create a blob from the response
  const blob = await response.blob();
  
  // Create a temporary URL for the blob
  const url = window.URL.createObjectURL(blob);
  
  // Create a temporary anchor element and click it to trigger the download
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  
  // Clean up
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
}