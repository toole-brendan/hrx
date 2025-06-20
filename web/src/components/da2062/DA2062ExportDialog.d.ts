import React from 'react';
interface Property {
    id: string;
    name: string;
    serialNumber: string;
    nsn?: string;
    category: string;
    status: string;
    isSensitive?: boolean;
}
interface DA2062ExportDialogProps {
    isOpen: boolean;
    onClose: () => void;
    selectedProperties?: Property[];
}
export declare const DA2062ExportDialog: React.FC<DA2062ExportDialogProps>;
export {};
