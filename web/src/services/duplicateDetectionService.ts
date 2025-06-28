import tokenService from './tokenService';
import { Property, BatchImportItem } from '@/types';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

export interface DuplicateCheckResult {
  hasDuplicates: boolean;
  duplicates: DuplicateItem[];
  uniqueItems: BatchImportItem[];
}

export interface DuplicateItem {
  importItem: BatchImportItem;
  existingItem: Property;
  matchType: 'serial_exact' | 'nsn_and_name' | 'serial_partial';
  confidence: number;
  suggestedAction: 'skip' | 'update' | 'create_anyway';
}

// Check for duplicates before import
export async function checkForDuplicates(items: BatchImportItem[]): Promise<DuplicateCheckResult> {
  const token = tokenService.getToken();
  if (!token) {
    throw new Error('No authentication token available');
  }

  try {
    const response = await fetch(`${API_BASE_URL}/property/check-duplicates`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ items }),
    });

    if (!response.ok) {
      // If endpoint doesn't exist, do client-side checking
      if (response.status === 404) {
        return clientSideDuplicateCheck(items);
      }
      throw new Error(`Failed to check duplicates: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    // Fallback to client-side checking
    console.warn('Server duplicate check failed, using client-side check:', error);
    return clientSideDuplicateCheck(items);
  }
}

// Client-side duplicate detection (fallback)
async function clientSideDuplicateCheck(items: BatchImportItem[]): Promise<DuplicateCheckResult> {
  const token = tokenService.getToken();
  if (!token) {
    throw new Error('No authentication token available');
  }

  // Fetch all existing properties
  const response = await fetch(`${API_BASE_URL}/property`, {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch existing properties');
  }

  const data = await response.json();
  const existingProperties: Property[] = data.properties || [];

  const duplicates: DuplicateItem[] = [];
  const uniqueItems: BatchImportItem[] = [];

  // Check each item for duplicates
  for (const item of items) {
    let foundDuplicate = false;

    for (const existing of existingProperties) {
      // Exact serial number match
      if (item.serialNumber && existing.serialNumber && 
          item.serialNumber.toLowerCase() === existing.serialNumber.toLowerCase()) {
        duplicates.push({
          importItem: item,
          existingItem: existing,
          matchType: 'serial_exact',
          confidence: 1.0,
          suggestedAction: 'skip',
        });
        foundDuplicate = true;
        break;
      }

      // NSN and name match (high probability duplicate)
      if (item.nsn && existing.nsn && item.nsn === existing.nsn &&
          normalizeString(item.name) === normalizeString(existing.name)) {
        duplicates.push({
          importItem: item,
          existingItem: existing,
          matchType: 'nsn_and_name',
          confidence: 0.9,
          suggestedAction: 'skip',
        });
        foundDuplicate = true;
        break;
      }

      // Partial serial number match (possible duplicate)
      if (item.serialNumber && existing.serialNumber && 
          item.serialNumber.length > 5 && existing.serialNumber.length > 5) {
        const similarity = calculateSimilarity(item.serialNumber, existing.serialNumber);
        if (similarity > 0.8) {
          duplicates.push({
            importItem: item,
            existingItem: existing,
            matchType: 'serial_partial',
            confidence: similarity,
            suggestedAction: 'update',
          });
          foundDuplicate = true;
          break;
        }
      }
    }

    if (!foundDuplicate) {
      uniqueItems.push(item);
    }
  }

  return {
    hasDuplicates: duplicates.length > 0,
    duplicates,
    uniqueItems,
  };
}

// Normalize string for comparison
function normalizeString(str: string): string {
  return str.toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .trim();
}

// Calculate string similarity (Levenshtein distance based)
function calculateSimilarity(str1: string, str2: string): number {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;

  if (longer.length === 0) {
    return 1.0;
  }

  const editDistance = levenshteinDistance(longer, shorter);
  return (longer.length - editDistance) / longer.length;
}

// Levenshtein distance calculation
function levenshteinDistance(str1: string, str2: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1,     // insertion
          matrix[i - 1][j] + 1      // deletion
        );
      }
    }
  }

  return matrix[str2.length][str1.length];
}

// Resolve duplicate action
export async function resolveDuplicate(
  duplicate: DuplicateItem,
  action: 'skip' | 'update' | 'create_anyway'
): Promise<void> {
  if (action === 'skip') {
    // Nothing to do
    return;
  }

  const token = tokenService.getToken();
  if (!token) {
    throw new Error('No authentication token available');
  }

  if (action === 'update') {
    // Update existing property with new information
    const updateData = {
      ...duplicate.existingItem,
      // Update fields from import item
      name: duplicate.importItem.name,
      nsn: duplicate.importItem.nsn || duplicate.existingItem.nsn,
      unitOfIssue: duplicate.importItem.unitOfIssue || duplicate.existingItem.unitOfIssue,
      conditionCode: duplicate.importItem.conditionCode || duplicate.existingItem.conditionCode,
      category: duplicate.importItem.category || duplicate.existingItem.category,
      manufacturer: duplicate.importItem.manufacturer || duplicate.existingItem.manufacturer,
      partNumber: duplicate.importItem.partNumber || duplicate.existingItem.partNumber,
    };

    const response = await fetch(`${API_BASE_URL}/property/${duplicate.existingItem.id}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(updateData),
    });

    if (!response.ok) {
      throw new Error(`Failed to update property: ${response.statusText}`);
    }
  }

  // For 'create_anyway', the normal import process will handle it
}

// Batch resolve duplicates
export async function batchResolveDuplicates(
  resolutions: Array<{ duplicate: DuplicateItem; action: 'skip' | 'update' | 'create_anyway' }>
): Promise<void> {
  for (const resolution of resolutions) {
    await resolveDuplicate(resolution.duplicate, resolution.action);
  }
}