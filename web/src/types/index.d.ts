import { LatLngExpression } from 'leaflet';
export interface User {
    id: string;
    email: string;
    name?: string;
    firstName?: string;
    lastName?: string;
    rank?: string;
    position?: string;
    unit?: string;
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
export interface Component {
    id: string;
    name: string;
    nsn?: string;
    serialNumber?: string;
    quantity: number;
    required: boolean;
    status: 'present' | 'missing' | 'damaged';
    notes?: string;
}
export interface CalibrationHistoryEntry {
    date: string;
    notes: string;
}
export interface CalibrationInfo {
    lastCalibrationDate?: string;
    nextCalibrationDueDate?: string;
    calibrationIntervalDays?: number;
    status?: 'current' | 'due-soon' | 'overdue' | undefined;
    notes?: string;
    history?: CalibrationHistoryEntry[];
}
export interface Property {
    id: string;
    name: string;
    description: string;
    serialNumber: string;
    nsn?: string;
    category: string;
    location: string;
    status: 'Operational' | 'Deadline - Maintenance' | 'Deadline - Supply' | 'Lost' | 'Non-Operational' | 'Damaged' | 'In Repair';
    assignedTo?: string;
    assignedDate?: string;
    lastInventoryDate?: string;
    acquisitionDate?: string;
    value?: number;
    isSensitive?: boolean;
    lastVerificationDate?: string;
    verificationIntervalDays?: number;
    verificationStatus?: 'current' | 'due-soon' | 'overdue';
    qrCode?: string;
    position?: LatLngExpression;
    requiresCalibration?: boolean;
    calibrationInfo?: CalibrationInfo;
    components?: Component[];
    isComponent?: boolean;
    parentItemId?: string;
    verified?: boolean;
    lin?: string;
}
export interface Transfer {
    id: string;
    name: string;
    serialNumber: string;
    from: string;
    to: string;
    date: string;
    status: "pending" | "approved" | "rejected";
    includeComponents?: boolean;
    approvedDate?: string;
    rejectedDate?: string;
    rejectionReason?: string;
}
export interface Activity {
    id: string;
    type: "transfer-approved" | "transfer-rejected" | "inventory-updated" | "other";
    description: string;
    user: string;
    timeAgo: string;
}
export interface Notification {
    id: string;
    type: "transfer-request" | "transfer-approved" | "system-alert" | "other";
    title: string;
    message: string;
    timeAgo: string;
    read: boolean;
}
export interface QRCode {
    id: string;
    inventoryItemId: string;
    qrCodeData: string;
    qrCodeHash: string;
    generatedByUserId: string;
    isActive: boolean;
    createdAt: string;
    deactivatedAt?: string;
}
export interface QRCodeWithItem extends QRCode {
    inventoryItem?: Property;
    qrCodeStatus: "active" | "damaged" | "missing" | "replaced";
    lastPrinted?: string;
    lastUpdated?: string;
}
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
export interface ConsumableItem {
    id: string;
    name: string;
    nsn?: string;
    category: string;
    unit: string;
    currentQuantity: number;
    minimumQuantity: number;
    location?: string;
    expirationDate?: string;
    notes?: string;
    lastRestockDate?: string;
}
