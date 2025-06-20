import React from 'react';
interface TransferConfirmationDialogProps {
    confirmation: {
        id: string;
        action: 'approve' | 'reject';
    } | null;
    isPending: boolean;
    transferName?: string;
    onClose: () => void;
    onConfirm: (id: string, action: 'approve' | 'reject') => void;
}
declare const TransferConfirmationDialog: React.FC<TransferConfirmationDialogProps>;
export default TransferConfirmationDialog;
