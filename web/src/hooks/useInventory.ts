import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useToast } from '@/hooks/use-toast';
import {
  fetchInventoryItems,
  fetchUserInventoryItems,
  fetchInventoryItem,
  createInventoryItem,
  updateInventoryItemStatus,
  verifyInventoryItem,
  fetchInventoryItemHistory,
  queueOfflineOperation,
  processOfflineQueue,
} from '@/services/inventoryService';
import { InventoryItem } from '@/types';

// Query keys
export const inventoryKeys = {
  all: ['inventory'] as const,
  lists: () => [...inventoryKeys.all, 'list'] as const,
  list: (filters?: { userId?: number }) => [...inventoryKeys.lists(), filters] as const,
  details: () => [...inventoryKeys.all, 'detail'] as const,
  detail: (id: string) => [...inventoryKeys.details(), id] as const,
  history: (serialNumber: string) => [...inventoryKeys.all, 'history', serialNumber] as const,
};

// Fetch all inventory items
export function useInventoryItems() {
  return useQuery({
    queryKey: inventoryKeys.lists(),
    queryFn: fetchInventoryItems,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
    retry: (failureCount, error: any) => {
      // Don't retry on 401/403
      if (error?.response?.status === 401 || error?.response?.status === 403) {
        return false;
      }
      return failureCount < 3;
    },
  });
}

// Fetch inventory items for a specific user
export function useUserInventoryItems(userId?: number) {
  return useQuery({
    queryKey: inventoryKeys.list({ userId }),
    queryFn: () => (userId ? fetchUserInventoryItems(userId) : fetchInventoryItems()),
    enabled: true, // Always enabled, will fetch all if no userId
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
}

// Fetch a single inventory item
export function useInventoryItem(id: string) {
  return useQuery({
    queryKey: inventoryKeys.detail(id),
    queryFn: () => fetchInventoryItem(id),
    enabled: !!id,
    staleTime: 5 * 60 * 1000,
    gcTime: 10 * 60 * 1000,
  });
}

// Fetch inventory item history
export function useInventoryItemHistory(serialNumber: string) {
  return useQuery({
    queryKey: inventoryKeys.history(serialNumber),
    queryFn: () => fetchInventoryItemHistory(serialNumber),
    enabled: !!serialNumber,
    staleTime: 30 * 60 * 1000, // 30 minutes - history doesn't change often
    gcTime: 60 * 60 * 1000, // 1 hour
  });
}

// Create inventory item mutation
export function useCreateInventoryItem() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: createInventoryItem,
    onSuccess: (newItem) => {
      // Invalidate and refetch inventory lists
      queryClient.invalidateQueries({ queryKey: inventoryKeys.lists() });
      
      // Optionally add the new item to the cache immediately
      queryClient.setQueryData<InventoryItem[]>(
        inventoryKeys.lists(),
        (old) => (old ? [...old, newItem] : [newItem])
      );
      
      toast({
        title: 'Success',
        description: `Created ${newItem.name} (SN: ${newItem.serialNumber})`,
      });
    },
    onError: (error: any) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        const operation = queueOfflineOperation({
          type: 'create',
          data: error.config?.data,
        });
        
        toast({
          title: 'Queued for sync',
          description: 'Item will be created when connection is restored',
        });
      } else {
        toast({
          title: 'Error',
          description: error?.message || 'Failed to create inventory item',
          variant: 'destructive',
        });
      }
    },
  });
}

// Update inventory item status mutation
export function useUpdateInventoryItemStatus() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) =>
      updateInventoryItemStatus(id, status),
    onSuccess: (updatedItem) => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: inventoryKeys.lists() });
      queryClient.invalidateQueries({ queryKey: inventoryKeys.detail(updatedItem.id) });
      
      toast({
        title: 'Status Updated',
        description: `${updatedItem.name} status changed to ${updatedItem.status}`,
      });
    },
    onError: (error: any, variables) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        queueOfflineOperation({
          type: 'update',
          data: variables,
        });
        
        toast({
          title: 'Queued for sync',
          description: 'Status update will be applied when connection is restored',
        });
      } else {
        toast({
          title: 'Error',
          description: error?.message || 'Failed to update item status',
          variant: 'destructive',
        });
      }
    },
  });
}

// Update inventory item components mutation
export function useUpdateInventoryItemComponents() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ id, components }: { id: string; components: any[] }) => {
      // For now, we'll update the entire item with new components
      // In a real implementation, you'd have a specific endpoint for this
      const currentItem = queryClient.getQueryData<InventoryItem>(inventoryKeys.detail(id));
      if (!currentItem) throw new Error('Item not found');
      
      // Return updated item with new components
      return { ...currentItem, components } as InventoryItem;
    },
    onSuccess: (updatedItem) => {
      // Update cache directly
      queryClient.setQueryData(inventoryKeys.detail(updatedItem.id), updatedItem);
      
      // Also update in the list
      queryClient.setQueryData<InventoryItem[]>(
        inventoryKeys.lists(),
        (old) => old?.map(item => item.id === updatedItem.id ? updatedItem : item) || []
      );
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to update components',
        variant: 'destructive',
      });
    },
  });
}

// Verify inventory item mutation
export function useVerifyInventoryItem() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: ({ id, verificationType }: { id: string; verificationType: string }) =>
      verifyInventoryItem(id, verificationType),
    onSuccess: (_, variables) => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: inventoryKeys.detail(variables.id) });
      
      toast({
        title: 'Verification Logged',
        description: 'Item verification has been recorded in the ledger',
      });
    },
    onError: (error: any, variables) => {
      // Queue for offline sync if network error
      if (!navigator.onLine || error?.message?.includes('network')) {
        queueOfflineOperation({
          type: 'verify',
          data: variables,
        });
        
        toast({
          title: 'Queued for sync',
          description: 'Verification will be logged when connection is restored',
        });
      } else {
        toast({
          title: 'Error',
          description: error?.message || 'Failed to verify item',
          variant: 'destructive',
        });
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
        // Invalidate all inventory queries to refresh data
        queryClient.invalidateQueries({ queryKey: inventoryKeys.all });
        
        toast({
          title: 'Sync Complete',
          description: `Processed ${result.processed} offline operations. ${result.remaining} remaining.`,
        });
      }
    },
    onError: (error: any) => {
      toast({
        title: 'Sync Error',
        description: error?.message || 'Failed to process offline queue',
        variant: 'destructive',
      });
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