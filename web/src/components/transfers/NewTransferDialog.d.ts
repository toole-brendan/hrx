import React from 'react';
interface NewTransferDialogProps {
    isOpen: boolean;
    currentUser: string;
    isPending: boolean;
    onClose: () => void;
    onSubmit: (data: {
        itemName: string;
        serialNumber: string;
        to: string;
    }) => void;
}
declare const NewTransferDialog: React.FC<NewTransferDialogProps>;
export default NewTransferDialog;
