import React from 'react';
interface FloatingActionButtonProps {
    onClick: () => void;
    icon: React.ReactNode;
    label?: string;
    position?: 'bottom-right' | 'bottom-left' | 'bottom-center';
    className?: string;
}
export declare const FloatingActionButton: React.FC<FloatingActionButtonProps>;
export {};
