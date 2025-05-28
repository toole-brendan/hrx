import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { useIsMobile } from '@/hooks/use-mobile';
import { useApp } from '@/contexts/AppContext';

interface ResponsiveContainerProps {
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
   * Display mode: 'flex' or 'block'
   */
  display?: 'flex' | 'block' | 'grid';
  /**
   * Flex direction if display is 'flex'
   */
  flexDirection?: 'row' | 'column';
}

/**
 * ResponsiveContainer - A container that automatically adjusts to different viewport sizes
 * Handles padding, width, and layout adaptively using CSS variables defined in index.css
 */
export const ResponsiveContainer: React.FC<ResponsiveContainerProps> = ({
  children,
  className,
  size = 'lg',
  withPadding = true,
  display = 'block',
  flexDirection = 'column',
}) => {
  const isMobile = useIsMobile();
  const { sidebarCollapsed } = useApp();
  
  // Define size classes that scale with the viewport
  const sizeClasses = {
    sm: 'max-w-2xl mx-auto',
    md: 'max-w-3xl mx-auto',
    lg: 'max-w-5xl mx-auto',
    xl: 'max-w-7xl mx-auto',
    full: 'w-full',
  };

  // Use our CSS defined page-wrapper class that has the responsive padding defined
  const paddingClasses = withPadding ? 'page-wrapper' : '';

  // Define display classes
  const displayClasses = {
    flex: `flex ${flexDirection === 'row' ? 'flex-row' : 'flex-col'}`,
    block: 'block',
    grid: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4',
  };
  
  // Main content classes for sidebar offset
  const mainContentClass = !isMobile 
    ? (sidebarCollapsed ? 'main-content sidebar-collapsed' : 'main-content')
    : '';

  return (
    <div
      className={cn(
        'transition-all duration-200',
        sizeClasses[size],
        paddingClasses,
        displayClasses[display],
        mainContentClass,
        className
      )}
    >
      {children}
    </div>
  );
};

export default ResponsiveContainer;