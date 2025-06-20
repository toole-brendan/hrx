const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

export interface SignatureData {
  signature: string; // Base64 encoded image
  timestamp: string;
}

// Upload signature
export async function uploadSignature(signatureData: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/users/signature`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify({ signature: signatureData }),
  });

  if (!response.ok) {
    throw new Error('Failed to upload signature');
  }
}

// Get user's signature
export async function getSignature(): Promise<string | null> {
  try {
    const response = await fetch(`${API_BASE_URL}/users/signature`, {
      method: 'GET',
      credentials: 'include',
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    return data.signature || null;
  } catch {
    return null;
  }
}

// Save signature locally
export function saveSignatureLocally(signature: string): void {
  localStorage.setItem('user_signature', signature);
  localStorage.setItem('signature_timestamp', new Date().toISOString());
}

// Get local signature
export function getLocalSignature(): SignatureData | null {
  const signature = localStorage.getItem('user_signature');
  const timestamp = localStorage.getItem('signature_timestamp');
  
  if (signature && timestamp) {
    return { signature, timestamp };
  }
  
  return null;
}

// Clear local signature
export function clearLocalSignature(): void {
  localStorage.removeItem('user_signature');
  localStorage.removeItem('signature_timestamp');
}