import React from 'react';
import { Transfer } from '@/types';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import StatusBadge from '@/components/common/StatusBadge';
import QRCodeGenerator from '@/components/common/QRCodeGenerator';
import BlockchainLedger from '@/components/blockchain/BlockchainLedger';
import { SensitiveItem, sensitiveItems } from '@/lib/sensitiveItemsData'; // Assuming these are needed for blockchain check
import { isBlockchainEnabled } from '@/lib/blockchain';
import { format, parseISO } from 'date-fns';
import { Loader2 } from 'lucide-react'; // Import Loader2

interface TransferDetailsModalProps {
  transfer: Transfer | null;
  isOpen: boolean;
  currentUser: string; // Needed for approve/reject button logic
  isUpdating: boolean; // To disable buttons during mutation
  onClose: () => void;
  onConfirmAction: (id: string, action: 'approve' | 'reject') => void; // To trigger confirmation
}

const TransferDetailsModal: React.FC<TransferDetailsModalProps> = ({
  transfer,
  isOpen,
  currentUser,
  isUpdating,
  onClose,
  onConfirmAction,
}) => {
  if (!transfer) return null;

  // Find related sensitive item if it exists
  const relatedSensitiveItem = sensitiveItems.find(item =>
    item.serialNumber === transfer.serialNumber
  );

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-2xl bg-card rounded-none"> {/* Added bg-card and rounded-none for consistency */}
        <DialogHeader>
          <DialogTitle>Transfer Details</DialogTitle>
          <DialogDescription>
            Information about transfer request ID: {transfer.id}
          </DialogDescription>
        </DialogHeader>

        {/* Transfer details content */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 py-4 max-h-[70vh] overflow-y-auto pr-2"> {/* Increased gap */}
          <div>
            <h3 className="text-sm font-semibold mb-3 text-muted-foreground uppercase tracking-wider">Basic Information</h3> {/* Styling update */}
            <div className="space-y-2.5 text-sm"> {/* Increased space */}
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Item:</span>
                <span className="font-medium text-right">{transfer.name}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Serial Number:</span>
                <span className="font-mono text-right">{transfer.serialNumber}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Status:</span>
                <StatusBadge status={transfer.status || 'pending'} />
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">From:</span>
                <span className="text-right">{transfer.from}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">To:</span>
                <span className="text-right">{transfer.to}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Request Date:</span>
                <span className="text-right">{format(parseISO(transfer.date), 'PPpp')}</span> {/* More detailed format */}
              </div>
              {transfer.approvedDate && (
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Approved Date:</span>
                  <span className="text-right">{format(parseISO(transfer.approvedDate), 'PPpp')}</span>
                </div>
              )}
              {transfer.rejectedDate && (
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Rejected Date:</span>
                  <span className="text-right">{format(parseISO(transfer.rejectedDate), 'PPpp')}</span>
                </div>
              )}
              {transfer.rejectionReason && (
                <div className="pt-2">
                  <span className="text-muted-foreground block mb-1">Rejection Reason:</span>
                  <p className="text-sm bg-muted/50 p-2 rounded">{transfer.rejectionReason}</p> {/* Styling update */}
                </div>
              )}
            </div>
          </div>

          <div>
            {/* QR Code for the transfer */}
            <h3 className="text-sm font-semibold mb-3 text-muted-foreground uppercase tracking-wider">Transfer QR Code</h3> {/* Styling update */}
            <div className="flex justify-center bg-white p-4 rounded-md border"> {/* Added border */}
              <QRCodeGenerator
                itemName={transfer.name}
                serialNumber={transfer.serialNumber}
              />
            </div>
            <p className="text-xs text-center text-muted-foreground mt-2">
              Scan this code to quickly access this transfer
            </p>
          </div>
        </div>

        {/* Blockchain ledger if this is a sensitive item */}
        {relatedSensitiveItem && isBlockchainEnabled(relatedSensitiveItem) && (
          <div className="py-4 border-t mt-4"> {/* Added border-t and margin */}
             <h3 className="text-sm font-semibold mb-3 text-muted-foreground uppercase tracking-wider">Secure Ledger History</h3> {/* Styling update */}
            <BlockchainLedger item={relatedSensitiveItem} />
          </div>
        )}

        <DialogFooter className="mt-4"> {/* Added margin */}
          <Button variant="outline" className="rounded-none" onClick={onClose}> {/* Added rounded-none */}
            Close
          </Button>
          {/* Add buttons for approve/reject if the transfer is pending and directed to the current user */}
          {transfer.status === 'pending' && transfer.to === currentUser && (
            <>
              <Button
                variant="destructive"
                className="rounded-none" // Added rounded-none
                onClick={() => onConfirmAction(transfer.id, 'reject')}
                disabled={isUpdating} // Use isUpdating prop
              >
                {isUpdating ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : null}
                Reject
              </Button>
              <Button
                variant="default" // Assuming default is green/accept style
                 className="rounded-none bg-green-600 hover:bg-green-700 text-white" // Explicit styling for approve
                onClick={() => onConfirmAction(transfer.id, 'approve')}
                disabled={isUpdating} // Use isUpdating prop
              >
                 {isUpdating ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : null}
                Approve
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default TransferDetailsModal; 