import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useToast } from '@/hooks/use-toast';
import { Property } from '@/types';

const API_BASE_URL = import.meta.env.DEV
  ? '/api'  // Use relative path in development to go through Vite proxy
  : (import.meta.env.VITE_API_URL || 'http://localhost:8000/api');

/** * Converts backend property format to frontend Property format */
function mapPropertyToProperty(property: any): Property {
  return {
    id: property.id.toString(),
    name: property.name,
    serialNumber: property.serial_number,
    status: property.current_status as Property['status'],
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

/** * Get authentication headers */
function getAuthHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json', // Cookie-based auth is handled automatically by fetch with credentials
  };
}

/** * Fetch all properties */
async function fetchProperties(): Promise<Property[]> {
  const response = await fetch(`${API_BASE_URL}/property`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include', // Include cookies for session auth
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch properties: ${response.statusText}`);
  }
  const data = await response.json();
  return (data.properties || []).map(mapPropertyToProperty);
}

/** * Fetch properties for a specific user */
async function fetchUserProperties(userId: number): Promise<Property[]> {
  const response = await fetch(`${API_BASE_URL}/property/user/${userId}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch user properties: ${response.statusText}`);
  }
  const data = await response.json();
  return (data.properties || []).map(mapPropertyToProperty);
}

/** * Fetch a single property by ID */
async function fetchProperty(id: string): Promise<Property> {
  const response = await fetch(`${API_BASE_URL}/property/${id}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch property: ${response.statusText}`);
  }
  const data = await response.json();
  return mapPropertyToProperty(data.property);
}

/** * Create a new property */
async function createProperty(input: { name: string; serialNumber: string; description?: string; currentStatus: string; propertyModelId?: number; assignedToUserId?: number; nsn?: string; lin?: string;
}): Promise<Property> {
  const response = await fetch(`${API_BASE_URL}/property`, {
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
    throw new Error(`Failed to create property: ${error}`);
  }
  const data = await response.json();
  return mapPropertyToProperty(data);
}

/** * Update property status */
async function updatePropertyStatus(id: string, status: string): Promise<Property> {
  const response = await fetch(`${API_BASE_URL}/property/${id}/status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ status }),
  });
  if (!response.ok) {
    throw new Error(`Failed to update property status: ${response.statusText}`);
  }
  const data = await response.json();
  return mapPropertyToProperty(data.property);
}

/** * Get property history from the ledger */
async function fetchPropertyHistory(serialNumber: string): Promise<any[]> {
  const response = await fetch(`${API_BASE_URL}/property/history/${serialNumber}`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch property history: ${response.statusText}`);
  }
  const data = await response.json();
  return data.history || [];
}

/** * Verify a property */
async function verifyProperty(id: string, verificationType: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/property/${id}/verify`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ verificationType }),
  });
  if (!response.ok) {
    throw new Error(`Failed to verify property: ${response.statusText}`);
  }
}

/** * Get components attached to a property */
async function fetchPropertyComponents(propertyId: string): Promise<any[]> {
  const response = await fetch(`${API_BASE_URL}/property/${propertyId}/components`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch property components: ${response.statusText}`);
  }
  const data = await response.json();
  return data.components || [];
}

/** * Attach a component to a property */
async function attachComponent(input: { propertyId: string; componentId: number; position?: string; notes?: string;
}): Promise<any> {
  const response = await fetch(`${API_BASE_URL}/property/${input.propertyId}/components`, {
    method: 'POST',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ componentId: input.componentId, position: input.position, notes: input.notes, }),
  });
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to attach component: ${error}`);
  }
  const data = await response.json();
  return data.attachment;
}

/** * Detach a component from a property */
async function detachComponent(propertyId: string, componentId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/property/${propertyId}/components/${componentId}`, {
    method: 'DELETE',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to detach component: ${response.statusText}`);
  }
}

/** * Get available components for attachment to a property */
async function fetchAvailableComponents(propertyId: string): Promise<Property[]> {
  const response = await fetch(`${API_BASE_URL}/property/${propertyId}/available-components`, {
    method: 'GET',
    headers: getAuthHeaders(),
    credentials: 'include',
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch available components: ${response.statusText}`);
  }
  const data = await response.json();
  return (data.availableComponents || []).map(mapPropertyToProperty);
}

/** * Update component position */
async function updateComponentPosition(input: { propertyId: string; componentId: number; position: string;
}): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/property/${input.propertyId}/components/${input.componentId}/position`, {
    method: 'PUT',
    headers: getAuthHeaders(),
    credentials: 'include',
    body: JSON.stringify({ position: input.position }),
  });
  if (!response.ok) {
    throw new Error(`Failed to update component position: ${response.statusText}`);
  }
}

/** * Sync queue for offline operations */
interface QueuedOperation {
  id: string;
  type: 'create' | 'update' | 'verify';
  data: any;
  timestamp: number;
}

const SYNC_QUEUE_KEY = 'handreceipt_sync_queue';

function queueOfflineOperation(operation: Omit<QueuedOperation, 'id' | 'timestamp'>) {
  const queue = getOfflineQueue();
  const newOp: QueuedOperation = { ...operation, id: crypto.randomUUID(), timestamp: Date.now(), };
  queue.push(newOp);
  localStorage.setItem(SYNC_QUEUE_KEY, JSON.stringify(queue));
  return newOp;
}

function getOfflineQueue(): QueuedOperation[] {
  try {
    const stored = localStorage.getItem(SYNC_QUEUE_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

async function processOfflineQueue() {
  const queue = getOfflineQueue();
  const processed: string[] = [];
  for (const operation of queue) {
    try {
      switch (operation.type) {
        case 'create':
          await createProperty(operation.data);
          break;
        case 'update':
          await updatePropertyStatus(operation.data.id, operation.data.status);
          break;
        case 'verify':
          await verifyProperty(operation.data.id, operation.data.verificationType);
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

// Query keys
export const propertyKeys = {
  all: ['property'] as const,
  lists: () => [...propertyKeys.all, 'list'] as const,
  list: (filters?: { userId?: number }) => [...propertyKeys.lists(), filters] as const,
  details: () => [...propertyKeys.all, 'detail'] as const,
  detail: (id: string) => [...propertyKeys.details(), id] as const,
  history: (serialNumber: string) => [...propertyKeys.all, 'history', serialNumber] as const,
  components: (propertyId: string) => [...propertyKeys.all, 'components', propertyId] as const,
  availableComponents: (propertyId: string) => [...propertyKeys.all, 'available-components', propertyId] as const,
};

// Fetch all properties
export function useProperties() {
  return useQuery({
    queryKey: propertyKeys.lists(),
    queryFn: fetchProperties,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
    retry: (failureCount, error: any) => {
      // Don't retry on 401/403 if (error?.response?.status === 401 || error?.response?.status === 403) {
      return false;
      // }
      // return failureCount < 3;
    },
  });
}

// Fetch properties for a specific user
export function useUserProperties(userId?: number) {
  return useQuery({
    queryKey: propertyKeys.list({ userId }),
    queryFn: () => (userId ? fetchUserProperties(userId) : fetchProperties()),
    enabled: true, // Always enabled, will fetch all if no userId
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
}

// Fetch a single property
export function useProperty(id: string) {
  return useQuery({
    queryKey: propertyKeys.detail(id),
    queryFn: () => fetchProperty(id),
    enabled: !!id,
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
}

// Fetch property history
export function usePropertyHistory(serialNumber: string) {
  return useQuery({
    queryKey: propertyKeys.history(serialNumber),
    queryFn: () => fetchPropertyHistory(serialNumber),
    enabled: !!serialNumber,
    staleTime: 30 * 60 * 1000, // 30 minutes - history doesn't change often
    gcTime: 60 * 60 * 1000, // 1 hour
  });
}

// Create property mutation
export function useCreateProperty() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: createProperty,
    onSuccess: (newItem) => {
      // Invalidate and refetch property lists
      queryClient.invalidateQueries({ queryKey: propertyKeys.lists() });
      // Optionally add the new item to the cache immediately
      queryClient.setQueryData<Property[]>(propertyKeys.lists(), (old) => (old ? [...old, newItem] : [newItem]));
      toast({ title: 'Success', description: `Created ${newItem.name} (SN: ${newItem.serialNumber})`, });
    },
    onError: (error: any) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        const operation = queueOfflineOperation({ type: 'create', data: error.config?.data });
        toast({ title: 'Queued for sync', description: 'Item will be created when connection is restored', });
      } else {
        toast({ title: 'Error', description: error?.message || 'Failed to create property', variant: 'destructive', });
      }
    },
  });
}

// Update property status mutation
export function useUpdatePropertyStatus() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => updatePropertyStatus(id, status),
    onSuccess: (updatedItem) => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: propertyKeys.lists() });
      queryClient.invalidateQueries({ queryKey: propertyKeys.detail(updatedItem.id) });
      toast({ title: 'Status Updated', description: `${updatedItem.name} status changed to ${updatedItem.status}`, });
    },
    onError: (error: any, variables) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        queueOfflineOperation({ type: 'update', data: variables });
        toast({ title: 'Queued for sync', description: 'Status update will be applied when connection is restored', });
      } else {
        toast({ title: 'Error', description: error?.message || 'Failed to update property status', variant: 'destructive', });
      }
    },
  });
}

// Update property components mutation
export function useUpdatePropertyComponents() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: async ({ id, components }: { id: string; components: any[] }) => {
      // For now, we'll update the entire item with new components
      // In a real implementation, you'd have a specific endpoint for this
      const currentItem = queryClient.getQueryData<Property>(propertyKeys.detail(id));
      if (!currentItem) throw new Error('Property not found');
      // Return updated property with new components
      return { ...currentItem, components } as Property;
    },
    onSuccess: (updatedItem) => {
      // Update cache directly
      queryClient.setQueryData(propertyKeys.detail(updatedItem.id), updatedItem);
      // Also update in the list
      queryClient.setQueryData<Property[]>(propertyKeys.lists(), (old) => old?.map(property => property.id === updatedItem.id ? updatedItem : property) || []);
    },
    onError: (error: any) => {
      toast({ title: 'Error', description: error?.message || 'Failed to update components', variant: 'destructive', });
    },
  });
}

// Verify property mutation
export function useVerifyProperty() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: ({ id, verificationType }: { id: string; verificationType: string }) => verifyProperty(id, verificationType),
    onSuccess: (_, variables) => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: propertyKeys.detail(variables.id) });
      toast({ title: 'Verification Logged', description: 'Property verification has been recorded in the ledger', });
    },
    onError: (error: any, variables) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        queueOfflineOperation({ type: 'verify', data: variables });
        toast({ title: 'Queued for sync', description: 'Verification will be logged when connection is restored', });
      } else {
        toast({ title: 'Error', description: error?.message || 'Failed to verify property', variant: 'destructive', });
      }
    },
  });
}

// Process offline queue
export function useProcessOfflineQueue() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: processOfflineQueue,
    onSuccess: (result) => {
      if (result.processed > 0) {
        // Invalidate all property queries to refresh data
        queryClient.invalidateQueries({ queryKey: propertyKeys.all });
        toast({ title: 'Sync Complete', description: `Processed ${result.processed} offline operations. ${result.remaining} remaining.`, });
      }
    },
    onError: (error: any) => {
      toast({ title: 'Sync Error', description: error?.message || 'Failed to process offline queue', variant: 'destructive', });
    },
  });
}

// Hook to monitor online status and process queue
export function useOfflineSync() {
  const processQueue = useProcessOfflineQueue();
  // Process queue when coming back online
  if (typeof window !== 'undefined') {
    window.addEventListener('online', () => {
      processQueue.mutate();
    });
  }
  return processQueue;
}

// Component-related hooks
// Fetch property components
export function usePropertyComponents(propertyId: string) {
  return useQuery({
    queryKey: propertyKeys.components(propertyId),
    queryFn: () => fetchPropertyComponents(propertyId),
    enabled: !!propertyId,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
  });
}

// Fetch available components for attachment
export function useAvailableComponents(propertyId: string) {
  return useQuery({
    queryKey: propertyKeys.availableComponents(propertyId),
    queryFn: () => fetchAvailableComponents(propertyId),
    enabled: !!propertyId,
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
}

// Attach component mutation
export function useAttachComponent() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: attachComponent,
    onSuccess: (attachment, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: propertyKeys.components(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.availableComponents(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.detail(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.lists() });
      toast({ title: 'Component Attached', description: 'Component has been successfully attached to the property', });
    },
    onError: (error: any) => {
      toast({ title: 'Error', description: error?.message || 'Failed to attach component', variant: 'destructive', });
    },
  });
}

// Detach component mutation
export function useDetachComponent() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: ({ propertyId, componentId }: { propertyId: string; componentId: number }) => detachComponent(propertyId, componentId),
    onSuccess: (_, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: propertyKeys.components(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.availableComponents(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.detail(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.lists() });
      toast({ title: 'Component Detached', description: 'Component has been successfully detached from the property', });
    },
    onError: (error: any) => {
      toast({ title: 'Error', description: error?.message || 'Failed to detach component', variant: 'destructive', });
    },
  });
}

// Update component position mutation
export function useUpdateComponentPosition() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  return useMutation({
    mutationFn: updateComponentPosition,
    onSuccess: (_, variables) => {
      // Invalidate and refetch relevant queries
      queryClient.invalidateQueries({ queryKey: propertyKeys.components(variables.propertyId) });
      queryClient.invalidateQueries({ queryKey: propertyKeys.detail(variables.propertyId) });
      toast({ title: 'Position Updated', description: 'Component position has been updated successfully', });
    },
    onError: (error: any) => {
      toast({ title: 'Error', description: error?.message || 'Failed to update component position', variant: 'destructive', });
    },
  });
} 