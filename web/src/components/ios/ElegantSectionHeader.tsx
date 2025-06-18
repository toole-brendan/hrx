import React from 'react';
import { cn } from '@/lib/utils';

interface ElegantSectionHeaderProps {
  title: string;
  subtitle?: string;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  divider?: boolean;
}

export const ElegantSectionHeader: React.FC<ElegantSectionHeaderProps> = ({
  title,
  subtitle,
  className,
  size = 'md',
  divider = false
}) => {
  const getSizeStyles = () => {
    switch (size) {
      case 'sm':
        return {
          title: 'text-xs font-bold',
          subtitle: 'text-xs'
        };
      case 'lg':
        return {
          title: 'text-sm font-bold',
          subtitle: 'text-sm'
        };
      default:
        return {
          title: 'text-xs font-bold',
          subtitle: 'text-xs'
        };
    }
  };

  const { title: titleStyles, subtitle: subtitleStyles } = getSizeStyles();

  return (
    <div className={cn('', className)}>
      <div className="flex flex-col gap-1">
        <h3 className={cn(
          'text-tertiary-text uppercase tracking-wide',
          titleStyles
        )}>
          {title}
        </h3>
        {subtitle && (
          <p className={cn(
            'text-quaternary-text',
            subtitleStyles
          )}>
            {subtitle}
          </p>
        )}
      </div>
      {divider && (
        <div className="mt-3 mb-4 h-px bg-ios-divider" />
      )}
    </div>
  );
}; 