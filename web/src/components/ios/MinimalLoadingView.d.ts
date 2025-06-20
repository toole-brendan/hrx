import React from 'react';
interface MinimalLoadingViewProps {
    size?: 'sm' | 'md' | 'lg';
    text?: string;
    className?: string;
    overlay?: boolean;
    variant?: 'spinner' | 'dots' | 'pulse';
}
export declare const MinimalLoadingView: React.FC<MinimalLoadingViewProps>;
export declare const LoadingDots: React.FC<{
    className?: string;
}>;
export declare const MinimalProgressBar: React.FC<{
    progress: number;
    className?: string;
}>;
export {};
