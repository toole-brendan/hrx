import React from 'react';
interface CategoryIndicatorProps {
    category: 'weapons' | 'communications' | 'optics' | 'vehicles' | 'electronics' | string;
    size?: 'sm' | 'md' | 'lg';
    className?: string;
}
export declare const CategoryIndicator: React.FC<CategoryIndicatorProps>;
export {};
