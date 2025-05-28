import React from 'react';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { CheckCircle, XCircle, Loader2 } from 'lucide-react';
import { Transfer } from '@/types';

interface TransferConfirmationDialogProps {
  confirmation: { id: string; action: 'approve' | 'reject' } | null;
  isPending: boolean;
  transferName?: string; // Optional name of the transfer item
  onClose: () => void;
  onConfirm: (id: string, action: 'approve' | 'reject') => void;
}

const TransferConfirmationDialog: React.FC<TransferConfirmationDialogProps> = ({
  confirmation,
  isPending,
  transferName = 'this item', // Default value
  onClose,
  onConfirm,
}) => {
  if (!confirmation) return null;

  const { id, action } = confirmation;
  const isApprove = action === 'approve';

  return (
    <AlertDialog open={true} onOpenChange={(open) => !open && onClose()}>
      <AlertDialogContent className="bg-card rounded-none">
        <AlertDialogHeader>
          <AlertDialogTitle>Confirm {isApprove ? 'Approval' : 'Rejection'}</AlertDialogTitle>
          <AlertDialogDescription>
            Are you sure you want to {action} this transfer request for item '{transferName}'?
            {!isApprove && ' This action cannot be undone.'}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel 
            className="rounded-none" 
            onClick={onClose}
          >
            Cancel
          </AlertDialogCancel>
          <AlertDialogAction
            className={`rounded-none ${isApprove ? 'bg-green-600 hover:bg-green-700 text-white' : 'bg-destructive hover:bg-destructive/90 text-destructive-foreground'}`}
            onClick={() => onConfirm(id, action)}
            disabled={isPending}
          >
            {isPending ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              isApprove ? <CheckCircle className="h-4 w-4 mr-2" /> : <XCircle className="h-4 w-4 mr-2" />
            )}
            Confirm {action.charAt(0).toUpperCase() + action.slice(1)}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
};

export default TransferConfirmationDialog; 