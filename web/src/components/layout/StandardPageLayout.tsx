import React, { ReactNode } from 'react';
import { PageHeader } from '@/components/ui/page-header';
import { cn } from '@/lib/utils';
import { usePageLayout } from '@/hooks/use-page-layout';

interface StandardPageLayoutProps {
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
 * StandardPageLayout - A consistent wrapper for all pages
 * Uses the usePageLayout hook for dynamic viewport scaling
 */
export function StandardPageLayout({
  title,
  description,
  actions,
  children,
  className,
  size = 'lg',
  withPadding = true,
  display = 'block'
}: StandardPageLayoutProps) {
  // Map size prop to width prop for usePageLayout
  const widthMap = {
    'sm': 'narrow',
    'md': 'default',
    'lg': 'wide',
    'xl': 'wide',
    'full': 'full'
  } as const;
  
  const { layoutClasses } = usePageLayout({
    width: widthMap[size] || 'default',
    fullWidth: size === 'full',
    basePadding: withPadding ? 'page-wrapper' : '',
    containerClasses: className,
    responsiveScaling: true
  });

  return (
    <div className={cn(
      'standard-page',
      display === 'flex' ? 'flex flex-col' : display === 'grid' ? 'grid' : '',
      layoutClasses
    )}>
      {title && (
        <PageHeader
          title={title}
          description={description}
          actions={actions}
          className="mb-2 sm:mb-3 md:mb-4" /* Reduced bottom margin */
        />
      )}
      <div className={cn(
        "w-full", 
        display === 'flex' ? 'flex-1 min-h-0' : ''
      )}>
        {children}
      </div>
    </div>
  );
}

export default StandardPageLayout;