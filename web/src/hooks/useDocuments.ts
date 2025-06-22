import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getDocuments, markAsRead, Document } from '@/services/documentService';

export const useDocuments = (box?: 'inbox' | 'sent' | 'all', status?: string, type?: string) => {
  return useQuery({
    queryKey: ['documents', box, status, type],
    queryFn: () => getDocuments(box, status),
    staleTime: 30000, // Consider data fresh for 30 seconds
  });
};

export const useUnreadDocumentCount = () => {
  return useQuery({
    queryKey: ['documents', 'inbox', 'unread'],
    queryFn: () => getDocuments('inbox', 'unread'),
    select: (data) => data.unread_count || 0,
    staleTime: 10000, // Refresh more frequently for notifications
    refetchInterval: 30000, // Auto-refresh every 30 seconds
  });
};

export const useMarkDocumentRead = () => {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: markAsRead,
    onSuccess: () => {
      // Invalidate all document queries to refresh counts and lists
      queryClient.invalidateQueries({ queryKey: ['documents'] });
    },
  });
};


// Export individual document query
export const useDocument = (id: number) => {
  return useQuery({
    queryKey: ['document', id],
    queryFn: () => fetch(`/api/documents/${id}`).then(res => res.json()),
    enabled: !!id,
  });
}; 