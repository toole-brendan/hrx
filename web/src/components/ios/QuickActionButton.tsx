import React from 'react';
import { cn } from '@/lib/utils';

interface QuickActionButtonProps {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary' | 'destructive';
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export const QuickActionButton: React.FC<QuickActionButtonProps> = ({
  icon,
  label,
  onClick,
  variant = 'primary',
  size = 'md',
  className
}) => {
  const getVariantStyles = () => {
    switch (variant) {
      case 'destructive':
        return 'bg-ios-destructive hover:bg-destructive-dim text-white';
      case 'secondary':
        return 'bg-gray-100 hover:bg-gray-200 text-primary-text border border-ios-border';
      default:
        return 'bg-ios-accent hover:bg-accent-hover text-white';
    }
  };

  const getSizeStyles = () => {
    switch (size) {
      case 'sm':
        return 'px-3 py-2 text-sm';
      case 'lg':
        return 'px-6 py-4 text-base';
      default:
        return 'px-4 py-3 text-sm';
    }
  };

  return (
    <button
      onClick={onClick}
      className={cn(
        'flex items-center gap-2 rounded-none font-medium transition-colors duration-200',
        getVariantStyles(),
        getSizeStyles(),
        className
      )}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}; 