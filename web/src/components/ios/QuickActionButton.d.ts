import React from 'react';
interface QuickActionButtonProps {
    icon: React.ReactNode;
    label: string;
    onClick: () => void;
    variant?: 'primary' | 'secondary' | 'destructive';
    size?: 'sm' | 'md' | 'lg';
    className?: string;
}
export declare const QuickActionButton: React.FC<QuickActionButtonProps>;
export {};
