import React, { useRef } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { Property } from '@/types';
import { CleanCard } from '@/components/ios';
import { format } from 'date-fns';
import { Package, AlertTriangle, CheckCircle, Clock, Wrench, Send } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';

interface VirtualPropertyListProps {
  properties: Property[];
  onPropertyClick: (property: Property) => void;
  onTransfer?: (property: Property) => void;
  isLoading?: boolean;
}

const PropertyRow: React.FC<{
  property: Property;
  onClick: () => void;
  onTransfer?: () => void;
}> = ({ property, onClick, onTransfer }) => {
  const statusConfig = {
    Operational: {
      color: 'text-green-600',
      bgColor: 'bg-green-50',
      icon: CheckCircle,
    },
    'Under Maintenance': {
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-50',
      icon: Wrench,
    },
    'Non-Operational': {
      color: 'text-red-600',
      bgColor: 'bg-red-50',
      icon: AlertTriangle,
    },
    'In Transit': {
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
      icon: Package,
    },
    default: {
      color: 'text-gray-600',
      bgColor: 'bg-gray-50',
      icon: Clock,
    },
  };

  const config = statusConfig[property.status as keyof typeof statusConfig] || statusConfig.default;
  const StatusIcon = config.icon;

  return (
    <div className="px-4 py-2">
      <CleanCard
        className="cursor-pointer hover:shadow-md transition-shadow"
        onClick={onClick}
      >
        <div className="flex items-center justify-between">
          <div className="flex-1">
            <h3 className="font-semibold text-ios-primary-text">
              {property.name}
            </h3>
            <div className="flex items-center gap-4 mt-1 text-sm text-ios-secondary-text">
              <span>SN: {property.serialNumber}</span>
              {property.nsn && <span>NSN: {property.nsn}</span>}
            </div>
          </div>
          
          <div className="flex items-center gap-3">
            {onTransfer && (
              <Button
                size="sm"
                variant="ghost"
                onClick={(e) => {
                  e.stopPropagation();
                  onTransfer();
                }}
                className="hover:bg-blue-50"
              >
                <Send className="h-4 w-4" />
              </Button>
            )}
            <div className={cn(
              'flex items-center gap-1.5 px-3 py-1 rounded-full text-sm font-medium',
              config.bgColor,
              config.color
            )}>
              <StatusIcon className="h-4 w-4" />
              <span>{property.status}</span>
            </div>
          </div>
        </div>
        
        {property.location && (
          <div className="mt-2 text-sm text-ios-tertiary-text">
            Location: {property.location}
          </div>
        )}
        
        <div className="mt-2 flex items-center justify-between text-xs text-ios-tertiary-text">
          <span>Updated: {format(new Date(property.updatedAt), 'MMM d, yyyy')}</span>
          {property.value && (
            <span className="font-medium">${property.value.toLocaleString()}</span>
          )}
        </div>
      </CleanCard>
    </div>
  );
};

export const VirtualPropertyList: React.FC<VirtualPropertyListProps> = ({
  properties,
  onPropertyClick,
  onTransfer,
  isLoading = false,
}) => {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: properties.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 120, // Estimated height of each row
    overscan: 5, // Number of items to render outside visible area
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-ios-primary-text" />
      </div>
    );
  }

  if (properties.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-64 text-ios-secondary-text">
        <Package className="h-12 w-12 mb-2 opacity-50" />
        <p>No properties found</p>
      </div>
    );
  }

  return (
    <div
      ref={parentRef}
      className="h-full overflow-auto"
      style={{
        contain: 'strict',
      }}
    >
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => {
          const property = properties[virtualItem.index];
          return (
            <div
              key={property.id}
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                width: '100%',
                height: `${virtualItem.size}px`,
                transform: `translateY(${virtualItem.start}px)`,
              }}
            >
              <PropertyRow
                property={property}
                onClick={() => onPropertyClick(property)}
                onTransfer={onTransfer ? () => onTransfer(property) : undefined}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
};