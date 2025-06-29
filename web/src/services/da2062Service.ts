import tokenService from './tokenService';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

// Helper function to safely parse JSON responses
async function parseJsonResponse(response: Response): Promise<any> {
  const contentType = response.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    try {
      return await response.json();
    } catch (e) {
      throw new Error(`Invalid JSON response: ${response.status} ${response.statusText}`);
    }
  }
  
  // Non-JSON response
  let errorMessage = `Server error: ${response.status} ${response.statusText}`;
  
  // Provide specific messages for common errors
  if (response.status === 401) {
    errorMessage = 'Authentication required. Please log in and try again.';
  } else if (response.status === 403) {
    errorMessage = 'Permission denied. You do not have access to this resource.';
  } else if (response.status === 404) {
    errorMessage = 'Resource not found. The requested endpoint does not exist.';
  } else if (response.status === 502 || response.status === 503) {
    errorMessage = 'Server is temporarily unavailable. Please try again later.';
  }
  
  throw new Error(errorMessage);
}

export interface DA2062Item {
  stockNumber?: string; // NSN
  itemDescription: string;
  quantity: number;
  unitOfIssue?: string;
  serialNumber?: string;
  confidence: number;
  quantityConfidence: number;
  hasExplicitSerial: boolean;
  // AI-enhanced fields
  suggestions?: AISuggestion[];
  aiGrouped?: boolean;
  validationIssues?: string[];
  needsReview?: boolean;
}

export interface AISuggestion {
  field: string;
  type: 'correction' | 'completion' | 'validation';
  value: string;
  confidence: number;
  reasoning: string;
}

export interface DA2062Form {
  unitName?: string;
  dodaac?: string;
  items: DA2062Item[];
  formNumber?: string;
  confidence: number;
  pageCount?: number;
  processedAt?: string;
  // AI-enhanced metadata
  metadata?: {
    itemCount: number;
    groupedItems: number;
    handwrittenItems: number;
    ocrConfidence: number;
    aiConfidence: number;
  };
  processingTimeMs?: number;
}

export interface EditableDA2062Item extends Omit<DA2062Item, 'quantity'> {
  id: string;
  description: string;
  nsn: string;
  quantity: string;
  serialNumber: string;
  unit?: string;
  isSelected: boolean;
  // DA 2062 fields
  unitOfIssue: string;
  conditionCode: string;
  category?: string;
  manufacturer?: string;
  partNumber?: string;
  securityClassification: string;
}

export interface BatchImportItem {
  name: string;
  serialNumber: string;
  nsn?: string;
  quantity: number;
  description?: string;
  unitOfIssue?: string;
  conditionCode?: string;
  category?: string;
  manufacturer?: string;
  partNumber?: string;
  securityClassification?: string;
  importMetadata?: {
    source: string;
    formReference?: string;
    confidence?: number;
    ocrConfidence?: number;
    serialSource?: string;
    extractedAt?: string;
    pageNumber?: number;
  };
}

export interface BatchImportResponse {
  items: unknown[];
  created_count: number;
  failed_count: number;
  total_attempted: number;
  verified_count: number;
  failed_items: Array<{
    item: BatchImportItem;
    error: string;
    reason: string;
  }>;
  summary?: any;
  message?: string;
  error?: string;
}

export interface UploadProgress {
  phase: 'uploading' | 'processing' | 'extracting' | 'parsing' | 'validating' | 'complete' | 'error';
  message: string;
  progress?: number;
}

// Upload and process DA-2062 document with Claude AI
export async function uploadDA2062(
  file: File,
  onProgress?: (progress: UploadProgress) => void
): Promise<DA2062Form> {
  try {
    // Upload phase
    onProgress?.({ phase: 'uploading', message: 'Uploading document...' });
    
    const formData = new FormData();
    formData.append('file', file);
    
    // Use Claude-powered upload endpoint (import route may not be deployed)
    const endpoint = `${API_BASE_URL}/da2062/upload`;
    
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: tokenService.getAuthHeaders(),
      body: formData,
      credentials: 'include',
    });

    if (!response.ok) {
      const error = await parseJsonResponse(response);
      throw new Error(error.error || 'Failed to upload document');
    }

    // Processing phase
    onProgress?.({ 
      phase: 'processing', 
      message: 'Processing with Claude AI...'
    });
    
    const result = await parseJsonResponse(response);
    
    // The backend returns the parsed DA2062 form directly
    if (result.error) {
      throw new Error(result.error);
    }
    
    // Transform the response to match expected format
    const form: DA2062Form = {
      unitName: result.form_info?.from_unit || '',
      dodaac: result.form_info?.dodaac || '',
      formNumber: result.form_info?.form_number || '',
      confidence: 0.85, // Default confidence
      items: result.items.map((item: any) => ({
        stockNumber: item.nsn,
        itemDescription: item.name,
        quantity: item.quantity,
        serialNumber: item.serialNumber,
        confidence: item.importMetadata?.scanConfidence || 0.85,
        quantityConfidence: 0.9,
        hasExplicitSerial: item.serialNumber && item.serialNumber !== 'N/A',
        needsReview: item.importMetadata?.requiresVerification || false
      })),
      metadata: {
        itemCount: result.total_items,
        groupedItems: 0,
        handwrittenItems: 0,
        ocrConfidence: 0.85,
        aiConfidence: 0.85
      }
    };
    
    onProgress?.({ phase: 'complete', message: 'Document processed successfully' });
    
    return form;
  } catch (error) {
    onProgress?.({ phase: 'error', message: error instanceof Error ? error.message : 'Processing failed' });
    throw error;
  }
}

// Export DA2062 as HTML
export async function exportDA2062(
  propertyIds: number[],
  options: {
    groupByCategory?: boolean;
    includeQRCodes?: boolean;
    sendEmail?: boolean;
    recipients?: string[];
    fromUser: any;
    toUser: any;
    unitInfo: any;
    toUserId?: number;
  }
): Promise<Blob> {
  const response = await fetch(`${API_BASE_URL}/da2062/generate-pdf`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
    body: JSON.stringify({
      property_ids: propertyIds,
      group_by_category: options.groupByCategory || false,
      include_qr_codes: options.includeQRCodes || false,
      send_email: options.sendEmail || false,
      recipients: options.recipients || [],
      from_user: options.fromUser,
      to_user: options.toUser,
      unit_info: options.unitInfo,
      to_user_id: options.toUserId
    }),
  });

  if (!response.ok) {
    const error = await parseJsonResponse(response);
    throw new Error(error.error || 'Failed to generate DA2062');
  }

  return response.blob();
}

// Batch import items from DA-2062
export async function batchImportItems(items: BatchImportItem[]): Promise<BatchImportResponse> {
  const response = await fetch(`${API_BASE_URL}/inventory/batch`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
    body: JSON.stringify({ items }),
  });

  let data;
  try {
    data = await parseJsonResponse(response);
  } catch (error) {
    // If JSON parsing fails on an error response, throw the error
    if (!response.ok) {
      throw error;
    }
    // If JSON parsing fails on a success response, that's a problem
    throw new Error('Invalid response format from server');
  }
  
  // Handle partial success (206) or success (201)
  if (response.status === 206 || response.status === 201) {
    return data;
  }
  
  // Handle complete failure
  if (!response.ok) {
    throw new Error(data.error || 'Failed to import items');
  }
  
  return data;
}

// Get unverified items
export async function getUnverifiedItems(): Promise<any[]> {
  const response = await fetch(`${API_BASE_URL}/da2062/unverified`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error('Failed to fetch unverified items');
  }

  return parseJsonResponse(response);
}

// Verify an imported item
export async function verifyImportedItem(
  itemId: number,
  data: { serialNumber?: string; nsn?: string }
): Promise<unknown> {
  const response = await fetch(`${API_BASE_URL}/da2062/verify/${itemId}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    const error = await parseJsonResponse(response);
    throw new Error(error.error || 'Failed to verify item');
  }

  return parseJsonResponse(response);
}

// Helper functions
export function generateSerialNumber(baseName: string, index: number): string {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const cleanBase = baseName
    .replace(/[^A-Z0-9]/gi, '')
    .toUpperCase()
    .slice(0, 8);
  return `GEN-${cleanBase}-${date}-${String(index).padStart(3, '0')}`;
}

export function getConfidenceColor(confidence: number): string {
  if (confidence >= 0.8) return 'text-green-600';
  if (confidence >= 0.6) return 'text-yellow-600';
  return 'text-red-600';
}

export function getConfidenceLabel(confidence: number): string {
  if (confidence >= 0.8) return 'High';
  if (confidence >= 0.6) return 'Medium';
  return 'Low';
}

export function formatNSN(nsn: string): string {
  if (!nsn || nsn.length !== 13) return nsn;
  return `${nsn.slice(0, 4)}-${nsn.slice(4, 6)}-${nsn.slice(6, 9)}-${nsn.slice(9)}`;
}

// AI-specific functions

// Generate DA2062 from natural language description
export async function generateDA2062FromDescription(
  description: string
): Promise<DA2062Form> {
  const response = await fetch(`${API_BASE_URL}/da2062/ai/generate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
    body: JSON.stringify({ description }),
  });

  if (!response.ok) {
    const error = await parseJsonResponse(response);
    throw new Error(error.error || 'Failed to generate DA2062');
  }

  const result = await parseJsonResponse(response);
  return result.form;
}

// Review and confirm AI-processed items
export async function reviewAndConfirmDA2062(
  formData: {
    formNumber: string;
    unitName: string;
    dodaac: string;
    items: any[];
    originalItems: any[];
  }
): Promise<{
  success: boolean;
  importedCount: number;
  properties: any[];
  formNumber: string;
}> {
  const response = await fetch(`${API_BASE_URL}/da2062/ai/review-confirm`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...tokenService.getAuthHeaders(),
    },
    credentials: 'include',
    body: JSON.stringify(formData),
  });

  if (!response.ok) {
    const error = await parseJsonResponse(response);
    throw new Error(error.error || 'Failed to confirm import');
  }

  return parseJsonResponse(response);
}

// Check if AI features are available
export async function checkAIAvailability(): Promise<boolean> {
  try {
    const response = await fetch(`${API_BASE_URL}/da2062/ai/health`, {
      method: 'GET',
      headers: tokenService.getAuthHeaders(),
      credentials: 'include',
    });
    
    if (response.ok) {
      const data = await parseJsonResponse(response);
      return data.available === true;
    }
    
    return false;
  } catch {
    return false;
  }
}