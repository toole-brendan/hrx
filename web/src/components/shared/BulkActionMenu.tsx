import React from 'react';
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { ArrowLeftRight, QrCode, Edit } from 'lucide-react'; // Example icons

interface BulkActionMenuProps {
  selectedItemCount: number;
  // availableActions: string[]; // Example: ['transfer', 'updateStatus', 'printQR'] - For enabling/disabling items later
  onActionTriggered: (action: string) => void; // Callback for when an action is selected
}

const BulkActionMenu: React.FC<BulkActionMenuProps> = ({
  selectedItemCount,
  onActionTriggered
}) => {
  if (selectedItemCount === 0) {
    return null; // Don't render if nothing is selected
  }

  return (
    <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50 ">
      <div className="bg-background dark:bg-gray-800 border border-border dark:border-gray-700 rounded-lg shadow-lg p-2 flex items-center gap-3">
        <span className="text-sm font-medium px-2 text-muted-foreground">
          {selectedItemCount} item{selectedItemCount > 1 ? 's' : ''} selected
        </span>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
             <Button variant="outline" size="sm">
                 Actions
             </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="center">
             {/* Dummy actions for now */}
            <DropdownMenuItem onClick={() => onActionTriggered('bulkTransfer')}>
               <ArrowLeftRight className="mr-2 h-4 w-4" />
               <span>Bulk Transfer</span>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => onActionTriggered('bulkUpdateStatus')}>
               <Edit className="mr-2 h-4 w-4" />
               <span>Update Status</span>
            </DropdownMenuItem>
             <DropdownMenuItem onClick={() => onActionTriggered('bulkPrintQR')}>
               <QrCode className="mr-2 h-4 w-4" />
               <span>Print QR Codes</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        {/* Maybe add a Cancel/Deselect All button here later */}
      </div>
    </div>
  );
};

export default BulkActionMenu; 