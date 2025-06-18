import React from 'react';
import { cn } from '@/lib/utils';
import { ChevronRight, Shield } from 'lucide-react';
import { StatusBadge } from './StatusBadge';
import { SerialNumberDisplay } from './IndustrialComponents';

interface ModernPropertyCardProps {
  property: {
    itemName: string;
    serialNumber?: string;
    status: 'operational' | 'maintenance' | 'non-operational';
    isSensitive?: boolean;
    category?: string;
  };
  onClick?: () => void;
  selected?: boolean;
  onSelect?: (selected: boolean) => void;
  className?: string;
}

export const ModernPropertyCard: React.FC<ModernPropertyCardProps> = ({
  property,
  onClick,
  selected,
  onSelect,
  className
}) => {
  return (
    <div
      className={cn(
        'bg-white border border-ios-border rounded-none p-4 hover:bg-gray-50 transition-colors',
        onClick && 'cursor-pointer',
        className
      )}
      onClick={onClick}
    >
      <div className="flex items-center gap-3">
        {onSelect && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              onSelect(!selected);
            }}
            className={cn(
              'w-5 h-5 border-2 rounded-full transition-colors',
              selected
                ? 'bg-ios-accent border-ios-accent'
                : 'border-gray-300 hover:border-ios-accent'
            )}
          />
        )}
        
        <div className="flex-1 min-w-0">
          <h3 className="font-semibold text-primary-text truncate">
            {property.itemName}
          </h3>
          
          {property.serialNumber && (
            <SerialNumberDisplay
              serialNumber={property.serialNumber}
              className="mt-1"
            />
          )}
          
          <div className="flex items-center gap-2 mt-2">
            <StatusBadge status={property.status} size="sm" />
            {property.isSensitive && (
              <span className="text-xs text-ios-warning flex items-center gap-1">
                <Shield className="w-3 h-3" />
                SENSITIVE
              </span>
            )}
          </div>
        </div>
        
        {onClick && <ChevronRight className="w-4 h-4 text-gray-400" />}
      </div>
    </div>
  );
}; 