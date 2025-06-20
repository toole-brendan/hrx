import React from 'react';
interface Property {
    id: number;
    name: string;
    serialNumber: string;
    nsn?: string;
    location?: string;
}
interface SendMaintenanceFormProps {
    property: Property;
    open: boolean;
    onClose: () => void;
}
export declare const SendMaintenanceForm: React.FC<SendMaintenanceFormProps>;
export {};
