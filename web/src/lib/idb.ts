import { openDB, DBSchema, IDBPDatabase } from 'idb';
import { InventoryItem, ConsumableItem } from '@/types'; // Importing ConsumableItem type
// Import other types as needed, e.g., Notification, SyncAction
import { Notification } from '@/contexts/NotificationContext';

// Define the SyncAction type (as per implementation plan)
export interface SyncAction {
  id: string; // uuid
  type: 'apiCall' | string; // Allow specific action types like 'createItem', 'updateTransfer'
  payload: {
    method: 'POST' | 'PUT' | 'DELETE';
    url: string; // The intended API endpoint
    data: any; // The request body
  };
  timestamp: number;
  status: 'pending' | 'syncing' | 'failed';
}

// Define consumption history entry type
export interface ConsumptionHistoryEntry {
  id: string;
  itemId: string; // Reference to a consumable
  quantity: number;
  date: string; // ISO date string
  issuedTo?: string;
  issuedBy?: string;
  notes?: string;
}

// 1. Define Database Schema
interface HandReceiptDB extends DBSchema {
  inventory: {
    key: string; // Using item.id as the key
    value: InventoryItem;
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

// 4. Basic CRUD operation helpers (Examples)

// --- Inventory Store Helpers ---
export async function getInventoryItemsFromDB(): Promise<InventoryItem[]> {
  const db = await getDb();
  return db.getAll('inventory');
}

export async function getInventoryItemFromDB(id: string): Promise<InventoryItem | undefined> {
    const db = await getDb();
    return db.get('inventory', id);
}

export async function saveInventoryItemsToDB(items: InventoryItem[]) {
  const db = await getDb();
  const tx = db.transaction('inventory', 'readwrite');
  await Promise.all(items.map(item => tx.store.put(item)));
  await tx.done;
  console.log(`${items.length} inventory items saved to DB.`);
}

export async function clearInventoryDB() {
    const db = await getDb();
    await db.clear('inventory');
    console.log('Inventory DB cleared.');
}

// --- Consumables Store Helpers ---
export async function getConsumablesFromDB(): Promise<ConsumableItem[]> {
  const db = await getDb();
  return db.getAll('consumables');
}

export async function getConsumableFromDB(id: string): Promise<ConsumableItem | undefined> {
  const db = await getDb();
  return db.get('consumables', id);
}

export async function saveConsumablesToDB(items: ConsumableItem[]) {
  const db = await getDb();
  const tx = db.transaction('consumables', 'readwrite');
  await Promise.all(items.map(item => tx.store.put(item)));
  await tx.done;
  console.log(`${items.length} consumable items saved to DB.`);
}

export async function deleteConsumableFromDB(id: string) {
  const db = await getDb();
  await db.delete('consumables', id);
  console.log(`Consumable item ${id} deleted from DB.`);
}

export async function updateConsumableQuantity(id: string, newQuantity: number) {
  const db = await getDb();
  const tx = db.transaction('consumables', 'readwrite');
  const item = await tx.store.get(id);
  
  if (item) {
    item.currentQuantity = newQuantity;
    await tx.store.put(item);
    console.log(`Consumable ${id} quantity updated to ${newQuantity}`);
  }
  
  await tx.done;
  return item;
}

// --- Consumption History Helpers ---
export async function getConsumptionHistoryFromDB(): Promise<ConsumptionHistoryEntry[]> {
  const db = await getDb();
  return db.getAll('consumptionHistory');
}

export async function getConsumptionHistoryByItemFromDB(itemId: string): Promise<ConsumptionHistoryEntry[]> {
  const db = await getDb();
  const index = db.transaction('consumptionHistory').store.index('by-itemId');
  return index.getAll(itemId);
}

export async function addConsumptionHistoryEntryToDB(entry: ConsumptionHistoryEntry) {
  const db = await getDb();
  await db.add('consumptionHistory', entry);
  console.log(`Consumption history entry ${entry.id} added to DB.`);
}

// --- Sync Queue Helpers ---
export async function addActionToSyncQueue(action: SyncAction) {
  const db = await getDb();
  await db.put('syncQueue', action);
  console.log(`Action ${action.type} (${action.id}) added to sync queue.`);
}

export async function getPendingSyncActions(): Promise<SyncAction[]> {
  const db = await getDb();
  // Get all actions and filter for pending (could also use an index if status indexed)
  const allActions = await db.getAllFromIndex('syncQueue', 'by-timestamp');
  return allActions.filter(action => action.status === 'pending').sort((a, b) => a.timestamp - b.timestamp);
}

export async function updateSyncActionStatus(id: string, status: 'syncing' | 'failed' | 'pending') {
  const db = await getDb();
  const action = await db.get('syncQueue', id);
  if (action) {
    await db.put('syncQueue', { ...action, status });
  }
}

export async function removeSyncAction(id: string) {
    const db = await getDb();
    await db.delete('syncQueue', id);
    console.log(`Sync action ${id} removed from queue.`);
}

// Add helpers for Notifications store if needed later (potentially replacing localStorage)

// --- Optimized Inventory Store Helpers ---

// Add a single item to the inventory
export async function addInventoryItemToDB(item: InventoryItem): Promise<void> {
  const db = await getDb();
  await db.add('inventory', item);
  console.log(`Inventory item ${item.id} added to DB.`);
}

// Update a single item in the inventory
export async function updateInventoryItemInDB(item: InventoryItem): Promise<void> {
  const db = await getDb();
  await db.put('inventory', item);
  console.log(`Inventory item ${item.id} updated in DB.`);
}

// Delete a single item from the inventory
export async function deleteInventoryItemFromDB(id: string): Promise<void> {
  const db = await getDb();
  await db.delete('inventory', id);
  console.log(`Inventory item ${id} deleted from DB.`);
}

// Get items by a specific category
export async function getInventoryItemsByCategoryFromDB(category: string): Promise<InventoryItem[]> {
  const db = await getDb();
  const allItems = await db.getAll('inventory');
  return allItems.filter(item => item.category === category);
}

// Search inventory items by name or serial number
export async function searchInventoryItemsFromDB(searchTerm: string): Promise<InventoryItem[]> {
  const db = await getDb();
  const allItems = await db.getAll('inventory');
  const lowerSearchTerm = searchTerm.toLowerCase();
  
  return allItems.filter(item => 
    (item.name && item.name.toLowerCase().includes(lowerSearchTerm)) || 
    (item.serialNumber && item.serialNumber.toLowerCase().includes(lowerSearchTerm))
  );
}

// Update component data for an item
export async function updateInventoryItemComponentsInDB(
  itemId: string, 
  components: any[]
): Promise<InventoryItem | undefined> {
  const db = await getDb();
  const tx = db.transaction('inventory', 'readwrite');
  const item = await tx.store.get(itemId);
  
  if (item) {
    item.components = components;
    await tx.store.put(item);
    await tx.done;
    console.log(`Components updated for item ${itemId}`);
    return item;
  }
  
  await tx.done;
  return undefined;
}

console.log('IndexedDB helper module loaded.'); 