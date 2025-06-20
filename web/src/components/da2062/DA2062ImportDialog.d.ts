import React from 'react';
interface DA2062ImportDialogProps {
    isOpen: boolean;
    onClose: () => void;
    onImportComplete?: (importedCount: number) => void;
}
export declare const DA2062ImportDialog: React.FC<DA2062ImportDialogProps>;
export {};
