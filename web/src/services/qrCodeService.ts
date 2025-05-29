const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';

/**
 * Generate SHA-256 hash using Web Crypto API
 */
async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return hashHex;
}

export interface QRCodeData {
  type: 'handreceipt_property';
  itemId: string;
  serialNumber: string;
  itemName: string;
  category: string;
  currentHolderId: string;
  timestamp: string;
  qrHash: string;
}

/**
 * Generate QR code data for an inventory item
 */
export async function generateQRCodeData(item: {
  id: string;
  serialNumber: string;
  name: string;
  category: string;
  assignedUserId?: string;
}): Promise<QRCodeData> {
  const data: Omit<QRCodeData, 'qrHash'> = {
    type: 'handreceipt_property',
    itemId: item.id,
    serialNumber: item.serialNumber,
    itemName: item.name,
    category: item.category,
    currentHolderId: item.assignedUserId || '',
    timestamp: new Date().toISOString(),
  };
  
  // Generate hash of the data for verification
  const dataString = JSON.stringify(data);
  const qrHash = await sha256(dataString);
  
  return { ...data, qrHash };
}

/**
 * Parse QR code data from scanned string
 */
export async function parseQRCodeData(qrString: string): Promise<QRCodeData | null> {
  try {
    const data = JSON.parse(qrString);
    
    // Validate required fields
    if (data.type !== 'handreceipt_property' || !data.itemId || !data.serialNumber) {
      return null;
    }
    
    // Verify hash integrity
    const { qrHash, ...dataWithoutHash } = data;
    const computedHash = await sha256(JSON.stringify(dataWithoutHash));
    
    if (computedHash !== qrHash) {
      console.warn('QR code hash verification failed');
      return null;
    }
    
    return data as QRCodeData;
  } catch (error) {
    console.error('Failed to parse QR code:', error);
    return null;
  }
}

/**
 * Generate QR code for an item (only current holder can do this)
 */
export async function generateItemQRCode(itemId: string): Promise<{
  qrCodeData: string;
  qrCodeUrl: string;
}> {
  const response = await fetch(`${API_BASE_URL}/inventory/${itemId}/qrcode`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
  });
  
  if (!response.ok) {
    throw new Error(`Failed to generate QR code: ${response.statusText}`);
  }
  
  return response.json();
}

/**
 * Initiate transfer by scanning QR code
 */
export async function initiateTransferByQR(qrData: QRCodeData): Promise<{
  transferId: string;
  status: string;
}> {
  const response = await fetch(`${API_BASE_URL}/transfers/qr-initiate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify({
      qrData,
      scannedAt: new Date().toISOString(),
    }),
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to initiate transfer: ${error}`);
  }
  
  return response.json();
} 