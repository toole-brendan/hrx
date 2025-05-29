import { InventoryItem } from '@/types';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';

/**
 * Converts backend property format to frontend InventoryItem format
 */
function mapPropertyToInventoryItem(property: any): InventoryItem {
  return {
    id: property.id.toString(),
    name: property.name,
    serialNumber: property.serial_number,
    status: property.current_status as InventoryItem['status'],
    description: property.description || '',
    category: property.category || 'other',
    location: property.location || '',
    assignedDate: property.assigned_date || new Date().toISOString(),
    components: property.components || [],
    isComponent: property.is_component || false,
    parentItemId: property.parent_item_id,
    nsn: property.nsn,
    assignedTo: property.assigned_to_user_id?.toString(),
  };
}

/**
 * Get authentication headers
 */
function getAuthHeaders(): HeadersInit {
  // TODO: Implement proper auth token retrieval from auth context
  return {
    'Content-Type': 'application/json',
    // Cookie-based auth is handled automatically by fetch with credentials
  };
}

/**
 * Fetch all inventory items
 */
export async function fetchInventoryItems(): Promise<InventoryItem[]> {
  const response = await fetch(`${API_BASE_URL}/inventory`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include', // Include cookies for session auth
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch inventory items: ${response.statusText}`);
  }

  const data = await response.json();
  return (data.items || []).map(mapPropertyToInventoryItem);
}

/**
 * Fetch inventory items for a specific user
 */
export async function fetchUserInventoryItems(userId: number): Promise<InventoryItem[]> {
  const response = await fetch(`${API_BASE_URL}/inventory/user/${userId}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch user inventory items: ${response.statusText}`);
  }

  const data = await response.json();
  return (data.items || []).map(mapPropertyToInventoryItem);
}

/**
 * Fetch a single inventory item by ID
 */
export async function fetchInventoryItem(id: string): Promise<InventoryItem> {
  const response = await fetch(`${API_BASE_URL}/inventory/${id}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch inventory item: ${response.statusText}`);
  }

  const data = await response.json();
  return mapPropertyToInventoryItem(data.item);
}

/**
 * Create a new inventory item
 */
export async function createInventoryItem(input: {
  name: string;
  serialNumber: string;
  description?: string;
  currentStatus: string;
  propertyModelId?: number;
  assignedToUserId?: number;
  nsn?: string;
  lin?: string;
}): Promise<InventoryItem> {
  const response = await fetch(`${API_BASE_URL}/inventory`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({
      name: input.name,
      serial_number: input.serialNumber,
      description: input.description,
      current_status: input.currentStatus,
      property_model_id: input.propertyModelId,
      assigned_to_user_id: input.assignedToUserId,
      nsn: input.nsn,
      lin: input.lin,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create inventory item: ${error}`);
  }

  const data = await response.json();
  return mapPropertyToInventoryItem(data);
}

/**
 * Update inventory item status
 */
export async function updateInventoryItemStatus(
  id: string,
  status: string
): Promise<InventoryItem> {
  const response = await fetch(`${API_BASE_URL}/inventory/${id}/status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ status }),
  });

  if (!response.ok) {
    throw new Error(`Failed to update inventory item status: ${response.statusText}`);
  }

  const data = await response.json();
  return mapPropertyToInventoryItem(data.item);
}

/**
 * Get inventory item history from the ledger
 */
export async function fetchInventoryItemHistory(serialNumber: string): Promise<any[]> {
  const response = await fetch(`${API_BASE_URL}/inventory/history/${serialNumber}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch inventory item history: ${response.statusText}`);
  }

  const data = await response.json();
  return data.history || [];
}

/**
 * Verify an inventory item
 */
export async function verifyInventoryItem(
  id: string,
  verificationType: string
): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/inventory/${id}/verify`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ verificationType }),
  });

  if (!response.ok) {
    throw new Error(`Failed to verify inventory item: ${response.statusText}`);
  }
}

/**
 * Sync queue for offline operations
 */
interface QueuedOperation {
  id: string;
  type: 'create' | 'update' | 'verify';
  data: any;
  timestamp: number;
}

const SYNC_QUEUE_KEY = 'handreceipt_sync_queue';

export function queueOfflineOperation(operation: Omit<QueuedOperation, 'id' | 'timestamp'>) {
  const queue = getOfflineQueue();
  const newOp: QueuedOperation = {
    ...operation,
    id: crypto.randomUUID(),
    timestamp: Date.now(),
  };
  queue.push(newOp);
  localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
  return newOp;
}

export function getOfflineQueue(): QueuedOperation[] {
  try {
    const stored = localStorage.getItem(SYNC_QUEUE_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

export async function processOfflineQueue() {
  const queue = getOfflineQueue();
  const processed: string[] = [];

  for (const operation of queue) {
    try {
      switch (operation.type) {
        case 'create':
          await createInventoryItem(operation.data);
          break;
        case 'update':
          await updateInventoryItemStatus(operation.data.id, operation.data.status);
          break;
        case 'verify':
          await verifyInventoryItem(operation.data.id, operation.data.verificationType);
          break;
      }
      processed.push(operation.id);
    } catch (error) {
      console.error('Failed to process offline operation:', operation, error);
    }
  }

  // Remove processed operations
  const remainingQueue = queue.filter(op => !processed.includes(op.id));
  localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(remainingQueue));

  return { processed: processed.length, remaining: remainingQueue.length };
} 