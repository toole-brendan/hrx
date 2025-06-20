import React, { ReactNode } from 'react';
interface PageHeaderProps {
    title: string;
    description?: string | ReactNode;
    actions?: ReactNode;
    className?: string;
} /** * PageHeader - 8VC style header component for page containers */
export declare function PageHeader({ title, description, actions, className }: PageHeaderProps): React.JSX.Element;
export default PageHeader;
