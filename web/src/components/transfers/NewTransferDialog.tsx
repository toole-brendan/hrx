import React from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Loader2, Send } from 'lucide-react';

interface NewTransferDialogProps {
  isOpen: boolean;
  currentUser: string;
  isPending: boolean;
  onClose: () => void;
  onSubmit: (data: { itemName: string; serialNumber: string; to: string }) => void;
}

const NewTransferDialog: React.FC<NewTransferDialogProps> = ({
  isOpen,
  currentUser,
  isPending,
  onClose,
  onSubmit,
}) => {
  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md bg-card rounded-none">
        <DialogHeader>
          <DialogTitle>Initiate Equipment Transfer</DialogTitle>
          <DialogDescription>
            Create a new transfer request to reassign equipment.
          </DialogDescription>
        </DialogHeader>
        <form id="new-transfer-form" onSubmit={(e) => {
          e.preventDefault();
          const formData = new FormData(e.currentTarget);
          onSubmit({
            itemName: formData.get('item-name') as string || 'Unknown Item',
            serialNumber: formData.get('serial-number') as string || 'N/A',
            to: formData.get('to') as string || 'Unknown Recipient',
          });
        }}>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="item-name">Item Name</Label>
              <Input id="item-name" name="item-name" placeholder="e.g., M4A1 Carbine" className="rounded-none" required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="serial-number">Serial Number</Label>
              <Input id="serial-number" name="serial-number" placeholder="e.g., W123456" className="rounded-none" required />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="from">From (Current Holder)</Label>
              <Input id="from" value={currentUser} disabled className="bg-muted/50 rounded-none" />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="to">To (Recipient)</Label>
              <Input id="to" name="to" placeholder="e.g., SFC Smith, Anna" className="rounded-none" required />
            </div>
          </div>
          <DialogFooter className="mt-4">
            <Button type="button" variant="outline" className="rounded-none" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant="blue" className="rounded-none" disabled={isPending}>
              {isPending ? (
                <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Send className="h-4 w-4 mr-2" />
              )}
              Send Transfer Request
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default NewTransferDialog; 