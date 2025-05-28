import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface PageHeaderProps {
  title: string;
  description?: string | ReactNode;
  actions?: ReactNode;
  className?: string;
}

/**
 * PageHeader - 8VC style header component for page containers
 */
export function PageHeader({ 
  title, 
  description, 
  actions, 
  className 
}: PageHeaderProps) {
  return (
    <div className={cn(
      "flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8 pb-4 border-b border-gray-200 dark:border-white/10",
      className
    )}>
      <div>
        <div className="category-tag mb-1.5 uppercase text-xs tracking-wider font-medium text-purple-600 dark:text-purple-400">
          {title.includes(' ') ? title.split(' ')[0] : 'Overview'}
        </div>
        <h1 className="heading-large text-2xl md:text-3xl font-semibold text-gray-900 dark:text-white tracking-tight">
          {title}
        </h1>
        {description && (
          <p className="mt-2 text-base text-gray-600 dark:text-gray-300 max-w-2xl">
            {description}
          </p>
        )}
      </div>
      {actions && (
        <div className="flex flex-wrap items-center gap-3 mt-3 sm:mt-0">
          {actions}
        </div>
      )}
    </div>
  );
};

export default PageHeader;