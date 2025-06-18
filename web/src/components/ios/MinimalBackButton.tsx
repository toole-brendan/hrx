import React from 'react';
import { cn } from '@/lib/utils';
import { ChevronLeft } from 'lucide-react';

interface MinimalBackButtonProps {
  onClick: () => void;
  label?: string;
  className?: string;
}

export const MinimalBackButton: React.FC<MinimalBackButtonProps> = ({
  onClick,
  label = 'Back',
  className
}) => {
  return (
    <button
      onClick={onClick}
      className={cn(
        'flex items-center gap-1 text-ios-accent hover:text-accent-hover transition-colors',
        className
      )}
    >
      <ChevronLeft className="w-4 h-4" />
      <span className="text-sm font-medium">{label}</span>
    </button>
  );
}; 