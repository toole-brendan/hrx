import React from 'react';
import { Transfer } from '@/types';
import { Button } from '@/components/ui/button';
import StatusBadge from '@/components/common/StatusBadge';
import { Loader2, MoreVertical } from 'lucide-react';
import { format, parseISO } from 'date-fns';

interface TransferRowProps {
  transfer: Transfer;
  currentUser: string; // Assuming string for comparison based on usage
  activeView: 'incoming' | 'outgoing' | 'history';
  isLoadingApprove: boolean;
  isLoadingReject: boolean;
  onConfirmAction: (id: string, action: 'approve' | 'reject') => void;
  onShowDetails: (transfer: Transfer) => void;
}

const TransferRow: React.FC<TransferRowProps> = ({
  transfer,
  currentUser,
  activeView,
  isLoadingApprove,
  isLoadingReject,
  onConfirmAction,
  onShowDetails,
}) => {
  const isRecipient = transfer.to === currentUser;
  const isSender = transfer.from === currentUser;
  const isPendingIncoming = activeView === 'incoming' && transfer.status === 'pending' && isRecipient;
  const isLoading = isLoadingApprove || isLoadingReject;

  return (
    <div className="grid grid-cols-[100px_1.5fr_1fr_1fr_120px_140px] gap-4 border-b px-4 py-4 hover:bg-muted/50 transition-colors text-sm items-center">
      {/* Date */}
      <div>
        <div className="font-medium">{format(parseISO(transfer.date), 'ddMMMyyyy').toUpperCase()}</div>
        <div className="text-xs text-muted-foreground">{format(parseISO(transfer.date), 'HH:mm')}</div>
      </div>

      {/* Item */}
      <div>
        <div className="font-medium truncate" title={transfer.name}>{transfer.name}</div>
        <div className="text-xs text-muted-foreground font-mono tracking-wider">SN: {transfer.serialNumber}</div>
      </div>

      {/* From */}
      <div className={`truncate ${isSender && activeView === 'history' ? 'font-semibold' : ''}`} title={transfer.from}>{transfer.from}</div>

      {/* To */}
      <div className={`truncate ${isRecipient && activeView === 'history' ? 'font-semibold' : ''}`} title={transfer.to}>{transfer.to}</div>

      {/* Status */}
      <div>
        <StatusBadge status={transfer.status} />
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end space-x-2">
        {isPendingIncoming ? (
          <>
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2 bg-transparent border-green-600 dark:border-green-500 text-green-600 dark:text-green-400 hover:bg-green-50 dark:hover:bg-green-900/20 uppercase text-[10px] tracking-wider rounded-none font-semibold"
              onClick={() => onConfirmAction(transfer.id, 'approve')}
              disabled={isLoading}
            >
              {isLoadingApprove ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Accept'}
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2 bg-transparent border-destructive/80 text-destructive hover:bg-destructive/10 uppercase text-[10px] tracking-wider rounded-none font-semibold"
              onClick={() => onConfirmAction(transfer.id, 'reject')}
              disabled={isLoading}
            >
              {isLoadingReject ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Decline'}
            </Button>
          </>
        ) : (
          <Button
            variant="ghost"
            size="sm"
            className="h-7 px-2 text-muted-foreground hover:text-foreground"
            onClick={() => onShowDetails(transfer)}
          >
            <MoreVertical className="h-4 w-4" />
            <span className="sr-only">Details</span>
          </Button>
        )}
      </div>
    </div>
  );
};

export default TransferRow; 