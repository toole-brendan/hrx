import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { useIsMobile } from '@/hooks/use-mobile';
import { useApp } from '@/contexts/AppContext';

interface PageWrapperProps {
  children: ReactNode;
  className?: string;
  /**
   * Whether to use full width layout
   */
  fullWidth?: boolean;
  /**
   * Whether to apply padding
   */
  withPadding?: boolean;
  /**
   * Content spacing to apply 
   */
  spacing?: 'none' | 'sm' | 'md' | 'lg';
}

/**
 * PageWrapper - A high-level wrapper that automatically handles
 * sidebar offset, responsive spacing, and alignment
 */
export function PageWrapper({
  children,
  className,
  fullWidth = false,
  withPadding = true,
  spacing = 'md',
} : PageWrapperProps) {
  const { sidebarCollapsed } = useApp();
  const isMobile = useIsMobile();
  
  const spacingClasses = {
    none: '',
    sm: 'space-y-2 md:space-y-3',
    md: 'space-y-4 md:space-y-6',
    lg: 'space-y-6 md:space-y-8',
  };
  
  return (
    <div className={cn(
      'page-wrapper',
      !isMobile && (sidebarCollapsed ? 'main-content sidebar-collapsed' : 'main-content'),
      withPadding ? 'page-wrapper' : '',
      fullWidth ? 'w-full' : 'max-w-[var(--content-max-width)] mx-auto',
      spacingClasses[spacing],
      className
    )}>
      {children}
    </div>
  );
}

export default PageWrapper;