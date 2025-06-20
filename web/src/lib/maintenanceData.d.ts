export type MaintenanceStatus = 'scheduled' | 'in-progress' | 'awaiting-parts' | 'bn-level' | 'completed' | 'cancelled';
export type MaintenancePriority = 'low' | 'medium' | 'high' | 'critical';
export type MaintenanceCategory = 'weapon' | 'vehicle' | 'communication' | 'optics' | 'other';
export type MaintenanceAction = 'created' | 'updated' | 'status-change' | 'parts-ordered' | 'parts-received' | 'completed';
export interface MaintenanceItem {
    id: string;
    itemId?: string;
    itemName: string;
    serialNumber: string;
    category: MaintenanceCategory;
    maintenanceType?: 'scheduled' | 'corrective' | 'preventive' | 'emergency';
    status: MaintenanceStatus;
    priority: MaintenancePriority;
    description: string;
    reportedBy: string;
    reportedDate: string;
    scheduledDate?: string;
    assignedTo?: string;
    estimatedCompletionTime?: string;
    completedDate?: string;
    notes?: string;
    partsRequired?: MaintenancePart[];
}
interface MaintenancePart {
    id: string;
    name: string;
    partNumber: string;
    quantity: number;
    available: boolean;
    estimatedArrival?: string;
}
export interface MaintenanceLog {
    id: string;
    maintenanceId: string;
    timestamp: string;
    action: MaintenanceAction;
    performedBy: string;
    notes: string;
}
export interface MaintenanceBulletin {
    id: string;
    title: string;
    message: string;
    category: 'parts-shortage' | 'delay' | 'update' | 'facility' | 'general';
    affectedItems?: string[];
    postedBy: string;
    postedDate: string;
    resolvedDate?: string;
    resolved: boolean;
}
export declare const maintenanceItems: MaintenanceItem[];
export declare const maintenanceLogs: MaintenanceLog[];
export declare const maintenanceBulletins: MaintenanceBulletin[];
export declare const maintenanceStats: {
    total: number;
    scheduled: number;
    inProgress: number;
    completed: number;
    cancelled: number;
    criticalPending: number;
};
export {};
