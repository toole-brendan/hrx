import { ReactNode } from 'react';
interface StandardPageLayoutProps {
    title?: string;
    description?: string | ReactNode;
    actions?: ReactNode;
    children: ReactNode;
    className?: string; /** * Container size preset */
    size?: 'sm' | 'md' | 'lg' | 'xl' | 'full'; /** * Whether to apply padding */
    withPadding?: boolean; /** * Display mode for content layout */
    display?: 'flex' | 'block' | 'grid';
} /** * StandardPageLayout - A consistent wrapper for all pages * Uses the usePageLayout hook for dynamic viewport scaling */
export declare function StandardPageLayout({ title, description, actions, children, className, size, withPadding, display }: StandardPageLayoutProps): void;
export default StandardPageLayout;
