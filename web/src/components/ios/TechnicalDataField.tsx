import React from 'react';
import { cn } from '@/lib/utils';

interface TechnicalDataFieldProps {
  label: string;
  value: string | number;
  type?: 'text' | 'number' | 'serial' | 'nsn';
  className?: string;
}

export const TechnicalDataField: React.FC<TechnicalDataFieldProps> = ({
  label,
  value,
  type = 'text',
  className
}) => {
  const getValueStyles = () => {
    switch (type) {
      case 'serial':
      case 'nsn':
        return 'font-mono text-ios-accent';
      case 'number':
        return 'font-mono text-primary-text';
      default:
        return 'text-primary-text';
    }
  };

  return (
    <div className={cn('flex flex-col gap-1', className)}>
      <label className="text-tertiary-text text-xs uppercase tracking-wide font-medium">
        {label}
      </label>
      <div className={cn('text-sm', getValueStyles())}>
        {value}
      </div>
    </div>
  );
}; 