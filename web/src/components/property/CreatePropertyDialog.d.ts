import React from 'react';
interface CreatePropertyDialogProps {
    isOpen: boolean;
    onClose: () => void;
    onSubmit: (data: {
        name: string;
        serialNumber: string;
        description?: string;
        category: string;
        nsn?: string;
        lin?: string;
        assignToSelf: boolean;
    }) => Promise<void>;
}
declare const CreatePropertyDialog: React.FC<CreatePropertyDialogProps>;
export default CreatePropertyDialog;
