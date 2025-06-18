import React from 'react';
import { cn } from '@/lib/utils';

// Technical data display component
export const TechnicalSpecs: React.FC<{
  specs: Array<{ label: string; value: string }>;
  className?: string;
}> = ({ specs, className }) => (
  <div className={cn('space-y-2', className)}>
    {specs.map((spec, index) => (
      <div key={index} className="flex justify-between items-center">
        <span className="text-tertiary-text text-sm font-medium uppercase tracking-wide">
          {spec.label}
        </span>
        <span className="text-primary-text font-mono text-sm">
          {spec.value}
        </span>
      </div>
    ))}
  </div>
);

// Serial number display
export const SerialNumberDisplay: React.FC<{
  serialNumber: string;
  className?: string;
}> = ({ serialNumber, className }) => (
  <div className={cn('font-mono text-ios-accent text-sm', className)}>
    {serialNumber}
  </div>
);

// Industrial divider
export const IndustrialDivider: React.FC<{
  className?: string;
}> = ({ className }) => (
  <div className={cn('h-px bg-ios-divider my-4', className)} />
);

// Export as default object for backwards compatibility
export const IndustrialComponents = {
  TechnicalSpecs,
  SerialNumberDisplay,
  IndustrialDivider
}; 