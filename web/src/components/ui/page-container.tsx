import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { PageHeader } from './page-header';
import ResponsiveContainer from './responsive-container';

interface PageContainerProps {
  title?: string;
  description?: string | ReactNode;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
  /**
   * Container size preset
   */
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  /**
   * Whether to apply padding
   */
  withPadding?: boolean;
  /**
   * Display mode for content layout
   */
  display?: 'flex' | 'block' | 'grid';
}

/**
 * PageContainer - A responsive container for page content
 * Uses the ResponsiveContainer component for consistent adaptive layout
 */
export const PageContainer: React.FC<PageContainerProps> = ({
  title,
  description,
  actions,
  children,
  className,
  size = 'lg',
  withPadding = true,
  display = 'block',
}) => {
  return (
    <ResponsiveContainer 
      size={size} 
      withPadding={withPadding}
      display={display === 'flex' ? 'flex' : display}
      flexDirection="column"
      className={cn("h-full", className)}
    >
      {title && (
        <PageHeader
          title={title}
          description={description}
          actions={actions}
          className="mb-2 sm:mb-3 md:mb-4" /* Reduced bottom margin */
        />
      )}
      <div className="w-full flex-1 min-h-0">
        {children}
      </div>
    </ResponsiveContainer>
  );
};

export default PageContainer;