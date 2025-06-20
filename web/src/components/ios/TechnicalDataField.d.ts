import React from 'react';
interface TechnicalDataFieldProps {
    label: string;
    value: string | number;
    type?: 'text' | 'number' | 'serial' | 'nsn';
    className?: string;
}
export declare const TechnicalDataField: React.FC<TechnicalDataFieldProps>;
export {};
