import { openDB, DBSchema, IDBPDatabase } from 'idb';
import { Property, Notification, ConsumableItem } from '@/types';

// Consumption history entry type
export interface ConsumptionHistoryEntry {
  id: string;
  itemId: string; // Reference to a consumable
  quantity: number;
  date: string; // ISO date string
  issuedTo?: string;
  issuedBy?: string;
  notes?: string;
}

// Sync action interface for offline operations
interface SyncAction {
  id: string;
  type: 'create' | 'update' | 'delete';
  entity: 'property' | 'transfer' | 'notification';
  data: any;
  timestamp: number;
}

// Database schema definition
interface HandReceiptDB extends DBSchema {
  inventory: {
    key: string; // Using item.id as the key
    value: Property;
    indexes: { 'by-name': string }; // Example index
  };
  consumables: {
    key: string; // Using item.id as key
    value: ConsumableItem;
    indexes: {
      'by-name': string;
      'by-category': string;
      'by-quantity': number;
    }
  };
  consumptionHistory: {
    key: string;
    value: ConsumptionHistoryEntry;
    indexes: {
      'by-date': string;
      'by-itemId': string;
    }
  };
  notifications: {
    key: string; // Using notification.id as key
    value: Notification;
    indexes: { 'by-timestamp': number };
  };
  syncQueue: {
    key: string; // Using action.id as key
    value: SyncAction;
    indexes: { 'by-timestamp': number };
  };
  // Add other stores as needed (e.g., 'transfers', 'settings')
}

// 2. Define DB Name and Version
const DB_NAME = 'HandReceiptDB';
const DB_VERSION = 2; // Increased version number for the schema update

let dbPromise: Promise<IDBPDatabase<HandReceiptDB>> | null = null;

// 3. Function to initialize the database
function getDb(): Promise<IDBPDatabase<HandReceiptDB>> {
  if (!dbPromise) {
    dbPromise = openDB<HandReceiptDB>(DB_NAME, DB_VERSION, {
      upgrade(db, oldVersion, newVersion, transaction) {
        console.log(`Upgrading DB from version ${oldVersion} to ${newVersion}`);
        
        // Create stores based on version changes
        if (oldVersion < 1) {
          // Create inventory store
          const inventoryStore = db.createObjectStore('inventory', { keyPath: 'id' });
          inventoryStore.createIndex('by-name', 'name');
          console.log('Created inventory object store');
          
          // Create notifications store
          const notificationStore = db.createObjectStore('notifications', { keyPath: 'id' });
          notificationStore.createIndex('by-timestamp', 'timestamp');
          console.log('Created notifications object store');
          
          // Create syncQueue store
          const syncQueueStore = db.createObjectStore('syncQueue', { keyPath: 'id' });
          syncQueueStore.createIndex('by-timestamp', 'timestamp');
          console.log('Created syncQueue object store');
        }
        
        // Add new stores for version 2
        if (oldVersion < 2) {
          // Create consumables store
          const consumablesStore = db.createObjectStore('consumables', { keyPath: 'id' });
          consumablesStore.createIndex('by-name', 'name');
          consumablesStore.createIndex('by-category', 'category');
          consumablesStore.createIndex('by-quantity', 'currentQuantity');
          console.log('Created consumables object store');
          
          // Create consumption history store
          const historyStore = db.createObjectStore('consumptionHistory', { keyPath: 'id' });
          historyStore.createIndex('by-date', 'date');
          historyStore.createIndex('by-itemId', 'itemId');
          console.log('Created consumption history object store');
        }
      },
      blocked() {
        console.warn('IndexedDB upgrade blocked. Please close other tabs using this app.');
        // Optionally notify the user
      },
      blocking() {
        console.warn('IndexedDB upgrade is blocking other instances. Closing DB connection.');
        // Close the connection to allow other tabs to upgrade.
        // This might be handled automatically by idb library in newer versions.
      },
      terminated() {
        console.error('IndexedDB connection terminated unexpectedly.');
        // Attempt to re-initialize the db connection
        dbPromise = null;
      },
    });
  }
  return dbPromise;
}

// 4. CRUD Operations for Properties
export async function addProperty(property: Property): Promise<void> {
  const db = await getDb();
  await db.add('inventory', property);
  console.log('Property added to IndexedDB:', property.id);
}

export async function getProperty(id: string): Promise<Property | undefined> {
  const db = await getDb();
  return await db.get('inventory', id);
}

export async function getAllProperties(): Promise<Property[]> {
  const db = await getDb();
  return await db.getAll('inventory');
}

export async function updateProperty(property: Property): Promise<void> {
  const db = await getDb();
  await db.put('inventory', property);
  console.log('Property updated in IndexedDB:', property.id);
}

export async function deleteProperty(id: string): Promise<void> {
  const db = await getDb();
  await db.delete('inventory', id);
  console.log('Property deleted from IndexedDB:', id);
}

// 5. CRUD Operations for Notifications
export async function addNotification(notification: Notification): Promise<void> {
  const db = await getDb();
  await db.add('notifications', notification);
  console.log('Notification added to IndexedDB:', notification.id);
}

export async function getAllNotifications(): Promise<Notification[]> {
  const db = await getDb();
  return await db.getAll('notifications');
}

export async function deleteNotification(id: string): Promise<void> {
  const db = await getDb();
  await db.delete('notifications', id);
  console.log('Notification deleted from IndexedDB:', id);
}

// 6. CRUD Operations for Consumables
export async function addConsumable(consumable: ConsumableItem): Promise<void> {
  const db = await getDb();
  await db.add('consumables', consumable);
  console.log('Consumable added to IndexedDB:', consumable.id);
}

export async function getAllConsumables(): Promise<ConsumableItem[]> {
  const db = await getDb();
  return await db.getAll('consumables');
}

export async function updateConsumable(consumable: ConsumableItem): Promise<void> {
  const db = await getDb();
  await db.put('consumables', consumable);
  console.log('Consumable updated in IndexedDB:', consumable.id);
}

export async function deleteConsumable(id: string): Promise<void> {
  const db = await getDb();
  await db.delete('consumables', id);
  console.log('Consumable deleted from IndexedDB:', id);
}

// 7. CRUD Operations for Consumption History
export async function addConsumptionHistory(entry: ConsumptionHistoryEntry): Promise<void> {
  const db = await getDb();
  await db.add('consumptionHistory', entry);
  console.log('Consumption history added to IndexedDB:', entry.id);
}

export async function getAllConsumptionHistory(): Promise<ConsumptionHistoryEntry[]> {
  const db = await getDb();
  return await db.getAll('consumptionHistory');
}

export async function getConsumptionHistoryByItem(itemId: string): Promise<ConsumptionHistoryEntry[]> {
  const db = await getDb();
  return await db.getAllFromIndex('consumptionHistory', 'by-itemId', itemId);
}

// 8. Sync Queue Operations
export async function addToSyncQueue(action: SyncAction): Promise<void> {
  const db = await getDb();
  await db.add('syncQueue', action);
  console.log('Action added to sync queue:', action.id);
}

export async function getAllSyncActions(): Promise<SyncAction[]> {
  const db = await getDb();
  return await db.getAll('syncQueue');
}

export async function clearSyncQueue(): Promise<void> {
  const db = await getDb();
  await db.clear('syncQueue');
  console.log('Sync queue cleared');
}

// 9. Utility Functions
export async function clearAllData(): Promise<void> {
  const db = await getDb();
  const tx = db.transaction(['inventory', 'notifications', 'syncQueue', 'consumables', 'consumptionHistory'], 'readwrite');
  
  await Promise.all([
    tx.objectStore('inventory').clear(),
    tx.objectStore('notifications').clear(),
    tx.objectStore('syncQueue').clear(),
    tx.objectStore('consumables').clear(),
    tx.objectStore('consumptionHistory').clear(),
  ]);
  
  await tx.done;
  console.log('All IndexedDB data cleared');
}

export async function getDbStats(): Promise<{ [storeName: string]: number }> {
  const db = await getDb();
  const stats: { [storeName: string]: number } = {};
  
  const storeNames = ['inventory', 'notifications', 'syncQueue', 'consumables', 'consumptionHistory'] as const;
  
  for (const storeName of storeNames) {
    const count = await db.count(storeName);
    stats[storeName] = count;
  }
  
  return stats;
}

console.log('IndexedDB helper module loaded.');

// Aliases for compatibility with ConsumablesManager
export const getConsumablesFromDB = getAllConsumables;
export const saveConsumablesToDB = async (consumables: ConsumableItem[]) => {
  const db = await getDb();
  const tx = db.transaction('consumables', 'readwrite');
  await tx.objectStore('consumables').clear();
  for (const consumable of consumables) {
    await tx.objectStore('consumables').add(consumable);
  }
  await tx.done;
};
export const deleteConsumableFromDB = deleteConsumable;
export const updateConsumableQuantity = async (id: string, quantity: number) => {
  const db = await getDb();
  const consumable = await db.get('consumables', id);
  if (consumable) {
    consumable.currentQuantity = quantity;
    await db.put('consumables', consumable);
  }
};
export const addConsumptionHistoryEntryToDB = addConsumptionHistory;
export const getConsumptionHistoryByItemFromDB = getConsumptionHistoryByItem; 