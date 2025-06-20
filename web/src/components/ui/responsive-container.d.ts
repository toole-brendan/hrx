import React, { ReactNode } from 'react';
interface ResponsiveContainerProps {
    children: ReactNode;
    className?: string; /** * Container size preset */
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full'; /** * Whether to apply padding */
    withPadding?: boolean; /** * Display mode: 'flex' or 'block' */
    display?: 'flex' | 'block' | 'grid'; /** * Flex direction if display is 'flex' */
    flexDirection?: 'row' | 'column';
} /** * ResponsiveContainer - A container that automatically adjusts to different viewport sizes * Handles padding, width, and layout adaptively using CSS variables defined in index.css */
export declare const ResponsiveContainer: React.FC<ResponsiveContainerProps>;
export default ResponsiveContainer;
