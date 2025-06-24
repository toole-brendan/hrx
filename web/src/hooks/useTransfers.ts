import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useToast } from '@/hooks/use-toast';
import { fetchTransfers, createTransfer, updateTransferStatus, getTransferById } from '@/services/transferService';
import { Transfer } from '@/types';
import { useAuth } from '@/contexts/AuthContext';

// Query keys
export const transferKeys = {
  all: ['transfers'] as const,
  lists: () => [...transferKeys.all, 'list'] as const,
  list: (filters?: { status?: string; direction?: string }) => [...transferKeys.lists(), filters] as const,
  details: () => [...transferKeys.all, 'detail'] as const,
  detail: (id: string) => [...transferKeys.details(), id] as const,
};

// Fetch all transfers
export function useTransfers(filters?: { status?: string; direction?: string }) {
  const { isAuthenticated, isLoading: authLoading } = useAuth();
  
  return useQuery({
    queryKey: transferKeys.list(filters),
    queryFn: fetchTransfers,
    enabled: isAuthenticated && !authLoading, // Only run query when authenticated
    staleTime: 2 * 60 * 1000, // 2 minutes - transfers change more frequently
    gcTime: 5 * 60 * 1000, // 5 minutes
  });
}

// Fetch a single transfer
export function useTransfer(id: string) {
  return useQuery({
    queryKey: transferKeys.detail(id),
    queryFn: () => getTransferById(id),
    enabled: !!id,
    staleTime: 2 * 60 * 1000,
    gcTime: 5 * 60 * 1000,
  });
}

// Create transfer mutation
export function useCreateTransfer() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  
  return useMutation({
    mutationFn: createTransfer,
    onSuccess: (newTransfer) => {
      // Invalidate and refetch transfer lists
      queryClient.invalidateQueries({ queryKey: transferKeys.lists() });
      toast({
        title: 'Transfer Requested',
        description: `Transfer request created for ${newTransfer.name}`,
      });
    },
    onError: (error: Error) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to create transfer request',
        variant: 'destructive',
      });
    },
  });
}

// Update transfer status mutation (approve/reject)
export function useUpdateTransferStatus() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  
  return useMutation({
    mutationFn: updateTransferStatus,
    onSuccess: (updatedTransfer, variables) => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: transferKeys.lists() });
      queryClient.invalidateQueries({ queryKey: transferKeys.detail(updatedTransfer.id) });
      
      // Also invalidate inventory queries as ownership may have changed
      queryClient.invalidateQueries({ queryKey: ['property'] });
      
      const action = variables.status === 'approved' ? 'approved' : 'rejected';
      toast({
        title: `Transfer ${action}`,
        description: `Transfer of ${updatedTransfer.name} has been ${action}`,
      });
    },
    onError: (error: any, variables) => {
      const action = variables.status === 'approved' ? 'approve' : 'reject';
      toast({
        title: 'Error',
        description: error?.message || `Failed to ${action} transfer`,
        variant: 'destructive',
      });
    },
  });
}

// Hook to get pending transfers count for notifications
export function usePendingTransfersCount() {
  const { data: transfers } = useTransfers({ status: 'pending' });
  return transfers?.filter(t => t.status === 'pending').length || 0;
}

// Hook to auto-refresh transfers when they're pending
export function useAutoRefreshTransfers() {
  const queryClient = useQueryClient();
  const { data: transfers } = useTransfers();
  
  // Auto-refresh if there are pending transfers
  const hasPending = transfers?.some(t => t.status === 'pending');
  
  if (hasPending && typeof window !== 'undefined') {
    const interval = setInterval(() => {
      queryClient.invalidateQueries({ queryKey: transferKeys.lists() });
    }, 30000); // Refresh every 30 seconds
    
    return () => clearInterval(interval);
  }
} 