import { cn } from '@/lib/utils';
import { useMemo } from 'react';
import { useIsMobile } from './use-mobile';
import { useApp } from '@/contexts/AppContext';

interface PageLayoutOptions {
  /**
   * Whether to use full width layout
   */
  fullWidth?: boolean;
  /**
   * Container width preset: 'default' | 'narrow' | 'wide' | 'full'
   */
  width?: 'default' | 'narrow' | 'wide' | 'full';
  /**
   * Base padding to apply
   */
  basePadding?: string;
  /**
   * Additional container classes
   */
  containerClasses?: string;
  /**
   * Whether to apply responsive scaling
   */
  responsiveScaling?: boolean;
  /**
   * Content spacing between children
   */
  spacing?: 'none' | 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  /**
   * Whether to apply animation effect
   */
  animate?: 'none' | 'fade-in' | 'slide-in';
}

/**
 * Hook for managing page layout properties consistently across the app
 * with improved viewport scaling and spacing
 */
export function usePageLayout({
  fullWidth = false,
  width = 'default',
  basePadding,
  containerClasses,
  responsiveScaling = true,
  spacing = 'none',
  animate = 'none',
}: PageLayoutOptions = {}) {
  const isMobile = useIsMobile();
  const { sidebarCollapsed } = useApp();
  
  // Use CSS variables for padding from our index.css
  const defaultPadding = 'page-wrapper';
  
  // Generate container width classes based on the width preset
  const containerWidth = useMemo(() => {
    if (fullWidth) return 'w-full';
    
    switch (width) {
      case 'narrow':
        return 'container-narrow';
      case 'wide':
        return 'container-wide';
      case 'full':
        return 'w-full';
      case 'default':
      default:
        return 'container-default';
    }
  }, [fullWidth, width]);

  // Apply responsive scaling classes if enabled
  const scaleClasses = useMemo(() => {
    return responsiveScaling ? 'responsive-scale' : '';
  }, [responsiveScaling]);
  
  // Generate spacing classes
  const spacingClasses = useMemo(() => {
    if (spacing === 'none') return '';
    return `spacing-${spacing}`;
  }, [spacing]);
  
  // Generate animation classes
  const animationClasses = useMemo(() => {
    if (animate === 'none') return '';
    return `animate-${animate}`;
  }, [animate]);

  // Main content classes based on sidebar state
  const mainContentClasses = useMemo(() => {
    return sidebarCollapsed ? 'main-content sidebar-collapsed' : 'main-content';
  }, [sidebarCollapsed]);

  const combinedClasses = useMemo(() => {
    const baseClasses = [
      basePadding || defaultPadding,
      containerWidth,
      scaleClasses,
      spacingClasses,
      animationClasses,
      isMobile ? '' : mainContentClasses, // Only apply main content classes if not mobile
      containerClasses
    ];
    
    return cn(...baseClasses);
  }, [
    basePadding, 
    defaultPadding, 
    containerWidth, 
    scaleClasses, 
    spacingClasses, 
    animationClasses, 
    mainContentClasses, 
    containerClasses, 
    isMobile
  ]);

  // Responsive page settings
  const pageSettings = useMemo(() => {
    return {
      hasResponsiveScaling: responsiveScaling,
      isMobile,
      sidebarCollapsed,
      isFullWidth: fullWidth || width === 'full',
      spacing,
      animate,
    };
  }, [responsiveScaling, isMobile, sidebarCollapsed, fullWidth, width, spacing, animate]);

  return {
    layoutClasses: combinedClasses,
    containerClasses: combinedClasses,
    mainContentClasses,
    containerWidth,
    defaultPadding,
    isMobile,
    spacingClasses,
    animationClasses,
    pageSettings,
  };
}