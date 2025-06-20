import React from 'react';
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { ArrowLeftRight, Edit } from 'lucide-react';

interface BulkActionMenuProps {
  selectedItemCount: number;
  onActionTriggered: (action: string) => void;
}

const BulkActionMenu: React.FC<BulkActionMenuProps> = ({
  selectedItemCount,
  onActionTriggered
}) => {
  if (selectedItemCount === 0) {
    return null; // Don't render if nothing is selected
  }

  return (
    <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-50">
      <div className="bg-background border border-border rounded-lg shadow-lg p-2 flex items-center gap-3">
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
            <DropdownMenuItem onClick={() => onActionTriggered('bulkTransfer')}>
              <ArrowLeftRight className="mr-2 h-4 w-4" />
              <span>Bulk Transfer</span>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => onActionTriggered('bulkUpdateStatus')}>
              <Edit className="mr-2 h-4 w-4" />
              <span>Update Status</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  );
};

export default BulkActionMenu; 