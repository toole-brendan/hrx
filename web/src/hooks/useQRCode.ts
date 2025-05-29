import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useToast } from '@/hooks/use-toast';
import { 
  generatePropertyQRCode, 
  getAllQRCodes, 
  getPropertyQRCodes, 
  reportQRCodeDamaged 
} from '@/services/qrCodeService';
import { QRCodeWithItem } from '@/types';

/**
 * Hook to fetch all QR codes with their inventory items
 */
export function useQRCodes() {
  return useQuery({
    queryKey: ['qrcodes'],
    queryFn: getAllQRCodes,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

/**
 * Hook to fetch QR codes for a specific property
 */
export function usePropertyQRCodes(propertyId: string) {
  return useQuery({
    queryKey: ['qrcodes', 'property', propertyId],
    queryFn: () => getPropertyQRCodes(propertyId),
    enabled: !!propertyId,
  });
}

/**
 * Hook to generate QR code for a property
 */
export function useGeneratePropertyQRCode() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: generatePropertyQRCode,
    onSuccess: (data, propertyId) => {
      // Invalidate QR code queries
      queryClient.invalidateQueries({ queryKey: ['qrcodes'] });
      queryClient.invalidateQueries({ queryKey: ['qrcodes', 'property', propertyId] });
      
      toast({
        title: 'QR Code Generated',
        description: 'QR code has been generated successfully',
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to generate QR code',
        variant: 'destructive',
      });
    },
  });
}

/**
 * Hook to report QR code as damaged
 */
export function useReportQRCodeDamaged() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: ({ qrCodeId, reason }: { qrCodeId: string; reason: string }) =>
      reportQRCodeDamaged(qrCodeId, reason),
    onSuccess: () => {
      // Invalidate QR code queries to refresh the list
      queryClient.invalidateQueries({ queryKey: ['qrcodes'] });
      
      toast({
        title: 'QR Code Reported',
        description: 'The QR code has been reported as damaged',
      });
    },
    onError: (error: any) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to report QR code as damaged',
        variant: 'destructive',
      });
    },
  });
}

/**
 * Hook to batch replace damaged QR codes
 */
export function useBatchReplaceDamagedQRCodes() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (damagedQRCodes: QRCodeWithItem[]) => {
      // For each damaged QR code, generate a new one
      const results = await Promise.allSettled(
        damagedQRCodes.map(qr => generatePropertyQRCode(qr.inventoryItemId))
      );
      
      const successful = results.filter(result => result.status === 'fulfilled').length;
      const failed = results.filter(result => result.status === 'rejected').length;
      
      return { successful, failed, total: damagedQRCodes.length };
    },
    onSuccess: (results) => {
      // Invalidate QR code queries
      queryClient.invalidateQueries({ queryKey: ['qrcodes'] });
      
      if (results.failed > 0) {
        toast({
          title: 'Batch Replace Completed with Errors',
          description: `${results.successful} QR codes replaced successfully, ${results.failed} failed`,
          variant: 'destructive',
        });
      } else {
        toast({
          title: 'Batch Replace Complete',
          description: `${results.successful} QR codes have been replaced successfully`,
        });
      }
    },
    onError: (error: any) => {
      toast({
        title: 'Batch Replace Failed',
        description: error?.message || 'Failed to replace damaged QR codes',
        variant: 'destructive',
      });
    },
  });
} 