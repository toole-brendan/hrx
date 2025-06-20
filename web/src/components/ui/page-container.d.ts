import React, { ReactNode } from 'react';
interface PageContainerProps {
    title?: string;
    description?: string | ReactNode;
    actions?: ReactNode;
    children: ReactNode;
    className?: string; /** * Container size preset */
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full'; /** * Whether to apply padding */
    withPadding?: boolean; /** * Display mode for content layout */
    display?: 'flex' | 'block' | 'grid';
} /** * PageContainer - A responsive container for page content * Uses the ResponsiveContainer component for consistent adaptive layout */
export declare const PageContainer: React.FC<PageContainerProps>;
export default PageContainer;
