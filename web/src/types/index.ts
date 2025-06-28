// @ts-ignore
import { LatLngExpression } from 'leaflet';

// Backend API Response Types
export interface BackendUser {
  id: number;
  name: string;
  rank: string;
  email: string;
  unit?: string;
}

export interface BackendProperty {
  id: number;
  name: string;
  serial_number: string;
  nsn?: string;
  category?: string;
}

export interface BackendTransfer {
  id: number;
  property?: BackendProperty;
  item_name?: string;
  serial_number?: string;
  from_user?: BackendUser;
  to_user?: BackendUser;
  from?: string;
  to?: string;
  request_date: string;
  resolved_date?: string;
  status: string;
  notes?: string;
}

export interface TransferOffer {
  id: number;
  property: {
    id: number;
    name: string;
    serialNumber: string;
  };
  offeringUser: {
    id: number;
    name: string;
    rank: string;
  };
  notes?: string;
  expiresAt?: string;
  createdAt: string;
}

export interface OfferResponse {
  id: number;
  message: string;
  offers: TransferOffer[];
}

// User Types
export interface User {
  id: string;
  email: string;
  name?: string;
  firstName?: string;
  lastName?: string;
  rank?: string;
  position?: string;
  unit?: string;
  phone?: string;
  yearsOfService?: number;
  commandTime?: string;
  responsibility?: string;
  valueManaged?: string;
  upcomingEvents?: Array<{
    title: string;
    date: string;
  }>;
  equipmentSummary?: {
    vehicles?: number;
    weapons?: number;
    communications?: number;
    opticalSystems?: number;
    sensitiveItems?: number;
  };
}

// Component Types for BII/COEI Tracking
export interface Component {
  id: string; // Client-generated or from mock data
  name: string;
  nsn?: string;
  serialNumber?: string;
  quantity: number;
  required: boolean;
  status: 'present' | 'missing' | 'damaged';
  notes?: string;
}

// --- Calibration Types ---
export interface CalibrationHistoryEntry {
  date: string; // ISO 8601 date string
  notes: string;
}

export interface CalibrationInfo {
  lastCalibrationDate?: string; // ISO 8601 date string
  nextCalibrationDueDate?: string; // ISO 8601 date string
  calibrationIntervalDays?: number;
  status?: 'current' | 'due-soon' | 'overdue' | undefined;
  notes?: string;
  history?: CalibrationHistoryEntry[];
}
// --- End Calibration Types ---

// Reference Data Types
export interface UnitOfIssueCode {
  code: string;
  description: string;
  category: string;
  sortOrder: number;
}

export interface PropertyCategory {
  code: string;
  name: string;
  description: string;
  isSensitive: boolean;
  defaultSecurityClass: string;
  sortOrder: number;
}

// Inventory Types
export interface Property {
  id: string;
  name: string;
  description: string;
  serialNumber: string;
  nsn?: string;
  lin?: string; // Line Item Number
  category?: string; // Property category code
  location: string; // Building/Room or Grid Coordinates
  status: 'Operational' | 'Deadline - Maintenance' | 'Deadline - Supply' | 'Lost' | 'Non-Operational' | 'Damaged' | 'In Repair'; // Updated to include new military-specific status options
  assignedTo?: string; // User ID or Name
  assignedDate?: string; // ISO 8601 date string
  lastInventoryDate?: string; // ISO 8601 date string
  acquisitionDate?: string; // ISO 8601 date string
  value?: number;
  isSensitive?: boolean;
  // DA 2062 required fields
  unitOfIssue: string; // Default 'EA'
  conditionCode: string; // A, B, or C
  manufacturer?: string;
  partNumber?: string;
  securityClassification: string; // U, FOUO, C, S
  // Fields to be removed
  // position?: LatLngExpression; // REMOVED - not needed for hand receipts
  // requiresCalibration?: boolean; // REMOVED
  // calibrationInfo?: CalibrationInfo; // REMOVED
  // components?: Component[]; // REMOVED - handled separately
  // isComponent?: boolean; // REMOVED
  // parentItemId?: string; // REMOVED
  updatedAt?: string; // ISO 8601 date string for last update
}

// Transfer Types
export interface Transfer {
  id: string;
  name: string;
  serialNumber: string;
  from: string;
  to: string;
  date: string; // ISO 8601 date string for request date
  status: "pending" | "approved" | "rejected";
  includeComponents?: boolean; // Whether attached components are included in transfer
  approvedDate?: string; // Optional: ISO 8601 date string for approval
  rejectedDate?: string; // Optional: ISO 8601 date string for rejection
  rejectionReason?: string; // Optional: Reason for rejection
}

// Activity Types
export interface Activity {
  id: string;
  type: "transfer-approved" | "transfer-rejected" | "inventory-updated" | "other";
  description: string;
  user: string;
  timeAgo: string;
}

// Notification Types
export interface Notification {
  id: string;
  type: "transfer-request" | "transfer-approved" | "system-alert" | "other";
  title: string;
  message: string;
  timeAgo: string;
  read: boolean;
}

// -----------
// Sensitive Items
// -----------
export interface SensitiveItem {
  id: string;
  name: string;
  category: 'weapon' | 'communication' | 'optics' | 'crypto' | 'other';
  serialNumber: string;
  assignedDate: string;
  status: 'verified' | 'pending' | 'overdue' | 'not-verified' | 'maintenance';
  lastVerified: string;
  nextVerification: string;
  securityLevel: 'routine' | 'controlled' | 'classified' | 'secret' | 'top-secret';
  location: string;
  assignedTo: string;
  notes?: string;
}

// -----------
// Consumables
// -----------
export interface ConsumableItem {
  id: string; // client-generated uuid
  name: string;
  nsn?: string;
  category: string; // e.g., Batteries, Cleaning Supplies, Medical, POL
  unit: string; // e.g., 'each', 'box', 'pack', 'gallon'
  currentQuantity: number;
  minimumQuantity: number;
  location?: string;
  expirationDate?: string; // Optional, ISO 8601 date string
  notes?: string;
  lastRestockDate?: string; // Optional, ISO 8601 date string
}
