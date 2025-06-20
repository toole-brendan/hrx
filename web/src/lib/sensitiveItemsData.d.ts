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
export interface VerificationLog {
    id: string;
    itemId: string;
    date: string;
    time: string;
    verifiedBy: string;
    status: 'verified' | 'missing' | 'damaged';
    notes?: string;
}
export interface SensitiveItemCategory {
    id: string;
    name: string;
    count: number;
    verificationFrequency: string;
    riskLevel: 'low' | 'medium' | 'high' | 'critical';
    icon: string;
}
export declare const sensitiveItems: SensitiveItem[];
export declare const verificationLogs: VerificationLog[];
export declare const sensitiveItemCategories: SensitiveItemCategory[];
export declare const verificationSchedule: {
    date: string;
    time: string;
    itemsToVerify: number;
    status: string;
}[];
export declare const sensitiveItemsStats: {
    totalItems: number;
    verifiedToday: number;
    pendingVerification: number;
    overdueVerification: number;
    inMaintenance: number;
    highRiskItems: number;
    lastFullVerification: string;
    verificationCompliance: string;
    itemsOverdue: number;
};
