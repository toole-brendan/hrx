import React from 'react';
interface BulkActionMenuProps {
    selectedItemCount: number;
    onActionTriggered: (action: string) => void;
}
declare const BulkActionMenu: React.FC<BulkActionMenuProps>;
export default BulkActionMenu;
