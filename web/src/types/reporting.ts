import { InventoryItem } from './index'; // Assuming InventoryItem is in index.ts

// Represents a category for readiness reporting
export interface ReadinessCategory {
  name: string;
  totalItems: number;
  fullyOperational: number;
  partiallyOperational: number;
  nonOperational: number;
  operationalPercentage: number; 
}

// Represents the overall readiness report structure
export interface ReadinessReport {
  generatedAt: string; // ISO timestamp string
  overallPercentage: number;
  categories: ReadinessCategory[];
  itemsNeedingAttention: InventoryItem[]; // List of items not fully operational
}

// Represents a line item in authorization data (e.g., MTOE/TDA)
export interface AuthorizationLineItem {
  id: string; // Can be NSN or other identifier
  name: string;
  requiredQuantity: number;
  category?: string; // Optional category for grouping
}

// Represents the overall structure for authorization data
export interface AuthorizationData {
  documentId: string; // e.g., MTOE document number
  documentDate: string; // Date of the document
  unitUIC: string; // Unit Identification Code
  lineItems: AuthorizationLineItem[];
}

// Represents a single shortage identified
export interface ShortageItem {
  authItemId: string; // Link to AuthorizationLineItem id (e.g., NSN)
  name: string;
  requiredQuantity: number;
  onHandQuantity: number;
  shortageQuantity: number;
}

// Represents the overall shortage report structure
export interface ShortageReport {
  generatedAt: string; // ISO timestamp string
  authorizationDocId: string;
  shortages: ShortageItem[];
  totalShortages: number;
} 