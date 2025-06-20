import React from 'react';
interface ModernPropertyCardProps {
    property: {
        itemName: string;
        serialNumber?: string;
        status: 'operational' | 'maintenance' | 'non-operational';
        isSensitive?: boolean;
        category?: string;
    };
    onClick?: () => void;
    selected?: boolean;
    onSelect?: (selected: boolean) => void;
    className?: string;
}
export declare const ModernPropertyCard: React.FC<ModernPropertyCardProps>;
export {};
