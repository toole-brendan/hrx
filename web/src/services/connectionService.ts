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

export async function searchUsers(query: string): Promise<SearchUserResult[]> {
  const response = await fetch(`${API_BASE_URL}/users/search?q=${encodeURIComponent(query)}`, {
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