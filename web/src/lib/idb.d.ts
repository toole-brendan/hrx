import { Property, Notification, ConsumableItem } from '@/types';
export interface ConsumptionHistoryEntry {
    id: string;
    itemId: string;
    quantity: number;
    date: string;
    issuedTo?: string;
    issuedBy?: string;
    notes?: string;
}
interface SyncAction {
    id: string;
    type: 'create' | 'update' | 'delete';
    entity: 'property' | 'transfer' | 'notification';
    data: any;
    timestamp: number;
}
export declare function addProperty(property: Property): Promise<void>;
export declare function getProperty(id: string): Promise<Property | undefined>;
export declare function getAllProperties(): Promise<Property[]>;
export declare function updateProperty(property: Property): Promise<void>;
export declare function deleteProperty(id: string): Promise<void>;
export declare function addNotification(notification: Notification): Promise<void>;
export declare function getAllNotifications(): Promise<Notification[]>;
export declare function deleteNotification(id: string): Promise<void>;
export declare function addConsumable(consumable: ConsumableItem): Promise<void>;
export declare function getAllConsumables(): Promise<ConsumableItem[]>;
export declare function updateConsumable(consumable: ConsumableItem): Promise<void>;
export declare function deleteConsumable(id: string): Promise<void>;
export declare function addConsumptionHistory(entry: ConsumptionHistoryEntry): Promise<void>;
export declare function getAllConsumptionHistory(): Promise<ConsumptionHistoryEntry[]>;
export declare function getConsumptionHistoryByItem(itemId: string): Promise<ConsumptionHistoryEntry[]>;
export declare function addToSyncQueue(action: SyncAction): Promise<void>;
export declare function getAllSyncActions(): Promise<SyncAction[]>;
export declare function clearSyncQueue(): Promise<void>;
export declare function clearAllData(): Promise<void>;
export declare function getDbStats(): Promise<{
    [storeName: string]: number;
}>;
export {};
