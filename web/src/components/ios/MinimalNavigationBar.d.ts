import React from 'react';
interface MinimalNavigationBarProps {
    title: string;
    leftAction?: React.ReactNode;
    rightAction?: React.ReactNode;
    className?: string;
    titleStyle?: 'default' | 'mono';
}
export declare const MinimalNavigationBar: React.FC<MinimalNavigationBarProps>;
export {};
