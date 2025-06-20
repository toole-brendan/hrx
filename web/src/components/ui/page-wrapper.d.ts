import React, { ReactNode } from 'react';
interface PageWrapperProps {
    children: ReactNode;
    className?: string; /** * Whether to use full width layout */
    fullWidth?: boolean; /** * Whether to apply padding */
    withPadding?: boolean; /** * Content spacing to apply */
    spacing?: 'none' | 'sm' | 'md' | 'lg';
} /** * PageWrapper - A high-level wrapper that automatically handles * sidebar offset, responsive spacing, and alignment */
export declare function PageWrapper({ children, className, fullWidth, withPadding, spacing, }: PageWrapperProps): React.JSX.Element;
export default PageWrapper;
