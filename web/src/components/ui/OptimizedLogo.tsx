import React from 'react';
import { ProgressiveImage } from './ProgressiveImage';

interface OptimizedLogoProps {
  variant?: 'default' | 'large';
  className?: string;
  onClick?: () => void;
}

export const OptimizedLogo: React.FC<OptimizedLogoProps> = ({ 
  variant = 'default', 
  className,
  onClick 
}) => {
  const logoSrc = variant === 'large' ? '/hr_logo4.png' : '/hr_logo.png';
  const defaultClassName = variant === 'large' 
    ? 'h-[200px] w-auto' 
    : 'h-8 w-auto';

  return (
    <picture onClick={onClick} className={onClick ? 'cursor-pointer' : undefined}>
      <source 
        srcSet={logoSrc.replace('.png', '.webp')} 
        type="image/webp" 
      />
      <ProgressiveImage
        src={logoSrc}
        alt="HandReceipt Logo"
        className={className || defaultClassName}
        loading="eager"
        placeholderSrc="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='50'%3E%3Crect width='100' height='50' fill='%23f3f4f6'/%3E%3C/svg%3E"
      />
    </picture>
  );
};