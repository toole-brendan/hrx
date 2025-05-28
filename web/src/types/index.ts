// @ts-ignore
import { LatLngExpression } from 'leaflet';

// User Types
export interface User {
  id: string;
  username: string;
  name: string;
  rank: string;
  position?: string;
  unit?: string;
  yearsOfService?: number;
  commandTime?: string;
  responsibility?: string;
  valueManaged?: string;
  upcomingEvents?: Array<{title: string; date: string;}>;
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

// Inventory Types
export interface InventoryItem {
  id: string;
  name: string;
  description: string;
  serialNumber: string;
  nsn?: string;
  category: string; // Weapon, Vehicle, Comms, Optics, Other
  location: string; // Building/Room or Grid Coordinates
  status: 'Operational' | 'Deadline - Maintenance' | 'Deadline - Supply' | 'Lost' | 'Non-Operational' | 'Damaged' | 'In Repair'; // Updated to include new military-specific status options
  assignedTo?: string; // User ID or Name
  assignedDate?: string; // ISO 8601 date string
  lastInventoryDate?: string; // ISO 8601 date string
  acquisitionDate?: string; // ISO 8601 date string
  value?: number;
  isSensitive?: boolean;
  lastVerificationDate?: string; // For sensitive items
  verificationIntervalDays?: number; // e.g., 30
  verificationStatus?: 'current' | 'due-soon' | 'overdue';
  qrCode?: string; // Could be data URL or identifier
  position?: LatLngExpression; // For map display
  requiresCalibration?: boolean;
  calibrationInfo?: CalibrationInfo;
  components?: Component[];
  isComponent?: boolean; // Flag if the item itself is a component
  parentItemId?: string; // Link to parent if it's a component
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
