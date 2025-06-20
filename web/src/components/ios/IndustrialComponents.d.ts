import React from 'react';
export declare const TechnicalSpecs: React.FC<{
    specs: Array<{
        label: string;
        value: string;
    }>;
    className?: string;
}>;
export declare const SerialNumberDisplay: React.FC<{
    serialNumber: string;
    className?: string;
}>;
export declare const IndustrialDivider: React.FC<{
    className?: string;
}>;
export declare const IndustrialComponents: {
    TechnicalSpecs: React.FC<{
        specs: Array<{
            label: string;
            value: string;
        }>;
        className?: string;
    }>;
    SerialNumberDisplay: React.FC<{
        serialNumber: string;
        className?: string;
    }>;
    IndustrialDivider: React.FC<{
        className?: string;
    }>;
};
