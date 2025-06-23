const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

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
}

export interface BatchImportItem {
  name: string;
  serialNumber: string;
  nsn?: string;
  quantity: number;
  description?: string;
  unitOfIssue?: string;
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

// Upload and process DA-2062 document
export async function uploadDA2062(
  file: File,
  onProgress?: (progress: UploadProgress) => void,
  useAI: boolean = true
): Promise<DA2062Form> {
  try {
    // Upload phase
    onProgress?.({ phase: 'uploading', message: 'Uploading document...' });
    
    const formData = new FormData();
    formData.append('file', file);
    
    // Use AI-enhanced endpoint if available and enabled
    const endpoint = useAI ? `${API_BASE_URL}/da2062/ai/process` : `${API_BASE_URL}/da2062/upload`;
    
    const response = await fetch(endpoint, {
      method: 'POST',
      body: formData,
      credentials: 'include',
    });

    if (!response.ok) {
      const error = await response.json();
      // Fall back to regular OCR if AI endpoint fails
      if (useAI && response.status === 404) {
        console.warn('AI endpoint not available, falling back to regular OCR');
        return uploadDA2062(file, onProgress, false);
      }
      throw new Error(error.error || 'Failed to upload document');
    }

    // Processing phase
    onProgress?.({ 
      phase: 'processing', 
      message: useAI ? 'Processing with AI-enhanced OCR...' : 'Processing document with OCR...' 
    });
    
    const result = await response.json();
    
    // The backend returns the parsed DA2062 form directly
    if (result.error) {
      throw new Error(result.error);
    }
    
    // If AI was used, we might get additional processing phases
    if (useAI && result.processingTimeMs) {
      onProgress?.({ 
        phase: 'validating', 
        message: 'AI validation complete',
        progress: 100
      });
    }
    
    onProgress?.({ phase: 'complete', message: 'Document processed successfully' });
    
    return result;
  } catch (error) {
    onProgress?.({ phase: 'error', message: error instanceof Error ? error.message : 'Processing failed' });
    throw error;
  }
}

// Batch import items from DA-2062
export async function batchImportItems(items: BatchImportItem[]): Promise<BatchImportResponse> {
  const response = await fetch(`${API_BASE_URL}/inventory/batch`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify({ items }),
  });

  const data = await response.json();
  
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
    },
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error('Failed to fetch unverified items');
  }

  return response.json();
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
    },
    credentials: 'include',
    body: JSON.stringify(data),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to verify item');
  }

  return response.json();
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
    },
    credentials: 'include',
    body: JSON.stringify({ description }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to generate DA2062');
  }

  const result = await response.json();
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
    },
    credentials: 'include',
    body: JSON.stringify(formData),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to confirm import');
  }

  return response.json();
}

// Check if AI features are available
export async function checkAIAvailability(): Promise<boolean> {
  try {
    const response = await fetch(`${API_BASE_URL}/da2062/ai/health`, {
      method: 'GET',
      credentials: 'include',
    });
    return response.ok;
  } catch {
    return false;
  }
}