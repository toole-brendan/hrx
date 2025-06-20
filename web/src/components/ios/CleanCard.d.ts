import React from 'react';
interface CleanCardProps {
    children: React.ReactNode;
    className?: string;
    padding?: 'none' | 'sm' | 'md' | 'lg';
    hoverable?: boolean;
    onClick?: () => void;
    selected?: boolean;
}
export declare const CleanCard: React.FC<CleanCardProps>;
export {};
