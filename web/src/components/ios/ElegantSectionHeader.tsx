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
          title: 'text-lg font-semibold', 
          subtitle: 'text-sm' 
        };
      case 'lg':
        return { 
          title: 'text-2xl font-semibold', 
          subtitle: 'text-base' 
        };
      default:
        return { 
          title: 'text-xl font-semibold', 
          subtitle: 'text-sm' 
        };
    }
  };

  const { title: titleStyles, subtitle: subtitleStyles } = getSizeStyles();

  return (
    <div className={cn('', className)}>
      <div className="flex flex-col gap-1">
        <h3 
          className={cn(
            'text-primary-text',
            titleStyles
          )}
          style={{ fontFamily: 'ui-serif, Georgia, serif' }}
        >
          {title}
        </h3>
        {subtitle && (
          <p className={cn(
            'text-secondary-text',
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