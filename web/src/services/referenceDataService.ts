import tokenService from './tokenService';
import { UnitOfIssueCode, PropertyCategory } from '@/types';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

// Cache for reference data
let unitOfIssueCache: UnitOfIssueCode[] | null = null;
let categoriesCache: PropertyCategory[] | null = null;

// Unit of issue codes
export async function getUnitOfIssueCodes(): Promise<UnitOfIssueCode[]> {
  if (unitOfIssueCache) {
    return unitOfIssueCache;
  }

  const token = tokenService.getToken();
  if (!token) {
    throw new Error('No authentication token available');
  }

  const response = await fetch(`${API_BASE_URL}/reference/unit-of-issue`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch unit of issue codes: ${response.statusText}`);
  }

  const data = await response.json();
  unitOfIssueCache = data.codes || [];
  return unitOfIssueCache;
}

// Property categories
export async function getPropertyCategories(): Promise<PropertyCategory[]> {
  if (categoriesCache) {
    return categoriesCache;
  }

  const token = tokenService.getToken();
  if (!token) {
    throw new Error('No authentication token available');
  }

  const response = await fetch(`${API_BASE_URL}/reference/categories`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch property categories: ${response.statusText}`);
  }

  const data = await response.json();
  categoriesCache = data.categories || [];
  return categoriesCache;
}

// Helper functions
export function getConditionCodes() {
  return [
    { code: 'A', label: 'Serviceable', description: 'New or good condition' },
    { code: 'B', label: 'Unserviceable (Repairable)', description: 'Needs repair but can be fixed' },
    { code: 'C', label: 'Unserviceable (Condemned)', description: 'Beyond repair' },
  ];
}

export function getSecurityClassifications() {
  return [
    { code: 'U', label: 'Unclassified' },
    { code: 'FOUO', label: 'For Official Use Only' },
    { code: 'C', label: 'Confidential' },
    { code: 'S', label: 'Secret' },
  ];
}

// Category helpers
export function detectCategoryFromDescription(description: string, categories: PropertyCategory[]): string | null {
  const lowerDesc = description.toLowerCase();
  
  // Check for exact matches first
  for (const category of categories) {
    if (lowerDesc.includes(category.name.toLowerCase())) {
      return category.code;
    }
  }
  
  // Check for common patterns
  const patterns: Record<string, string[]> = {
    'WEAPON': ['rifle', 'pistol', 'carbine', 'm4', 'm16', 'm9', 'weapon', 'gun'],
    'VEHICLE': ['truck', 'hmmwv', 'vehicle', 'trailer'],
    'COMMS': ['radio', 'antenna', 'phone', 'communication'],
    'OPTICS': ['scope', 'binocular', 'nvg', 'night vision', 'acog', 'optic'],
    'MEDICAL': ['medical', 'first aid', 'bandage', 'tourniquet'],
    'TOOL': ['tool', 'wrench', 'hammer', 'screwdriver'],
    'AMMO': ['ammo', 'round', 'grenade', 'magazine'],
    'GENERATOR': ['generator', 'genset'],
  };
  
  for (const [categoryCode, keywords] of Object.entries(patterns)) {
    if (keywords.some(keyword => lowerDesc.includes(keyword))) {
      return categoryCode;
    }
  }
  
  return null;
}

// Unit of issue helpers
export function detectUnitOfIssue(description: string, quantity: number): string {
  const lowerDesc = description.toLowerCase();
  
  // Check for specific patterns
  if (lowerDesc.includes('round') || lowerDesc.includes('ammo') || lowerDesc.includes('cartridge')) {
    return 'RD';
  }
  if (lowerDesc.includes('pair') || lowerDesc.includes('glove') || lowerDesc.includes('boot')) {
    return 'PR';
  }
  if (lowerDesc.includes('oil') || lowerDesc.includes('fuel') || lowerDesc.includes('coolant')) {
    return 'GAL';
  }
  if (lowerDesc.includes('cable') || lowerDesc.includes('rope') || lowerDesc.includes('wire')) {
    return 'FT';
  }
  if (lowerDesc.includes('box')) {
    return 'BX';
  }
  if (lowerDesc.includes('pack') || lowerDesc.includes('package')) {
    return 'PG';
  }
  
  // Default
  return 'EA';
}

// Clear cache (useful after updates)
export function clearReferenceDataCache() {
  unitOfIssueCache = null;
  categoriesCache = null;
}