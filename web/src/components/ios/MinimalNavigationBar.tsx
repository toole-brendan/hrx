import React from 'react';
import { cn } from '@/lib/utils';

interface MinimalNavigationBarProps {
  title: string;
  leftAction?: React.ReactNode;
  rightAction?: React.ReactNode;
  className?: string;
}

export const MinimalNavigationBar: React.FC<MinimalNavigationBarProps> = ({
  title,
  leftAction,
  rightAction,
  className
}) => {
  return (
    <div className={cn(
      'flex items-center justify-between px-4 py-3 bg-white border-b border-ios-border',
      className
    )}>
      <div className="flex items-center min-w-0 flex-1">
        {leftAction}
      </div>
      <div className="flex-1 text-center">
        <h1 className="text-lg font-semibold text-primary-text truncate">
          {title}
        </h1>
      </div>
      <div className="flex items-center min-w-0 flex-1 justify-end">
        {rightAction}
      </div>
    </div>
  );
}; 