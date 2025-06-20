import React from 'react';
interface ElegantSectionHeaderProps {
    title: string;
    subtitle?: string;
    className?: string;
    size?: 'sm' | 'md' | 'lg';
    divider?: boolean;
}
export declare const ElegantSectionHeader: React.FC<ElegantSectionHeaderProps>;
export {};
