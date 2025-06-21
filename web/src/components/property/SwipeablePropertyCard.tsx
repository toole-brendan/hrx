import React, { useState, useRef, useEffect } from 'react';
import { Property } from '@/types';
import { cn } from '@/lib/utils';
import { getCategoryFromName, getCategoryIcon, getCategoryColor, normalizeItemStatus } from '@/lib/propertyUtils';
import { CleanCard, StatusBadge } from '@/components/ios';
import { 
  Shield, 
  Info, 
  ArrowLeftRight, 
  Wrench, 
  Eye, 
  Calendar, 
  Package, 
  FileText,
  AlertTriangle,
  CheckCircle,
  Clock,
  ChevronRight,
  MoreVertical
} from 'lucide-react';

interface SwipeablePropertyCardProps {
  property: Property;
  isSelected: boolean;
  isSelectMode: boolean;
  onTap: () => void;
  onTransfer: () => void;
  onMaintenance?: () => void;
  onViewDetails?: () => void;
}

export const SwipeablePropertyCard: React.FC<SwipeablePropertyCardProps> = ({
  property,
  isSelected,
  isSelectMode,
  onTap,
  onTransfer,
  onMaintenance,
  onViewDetails
}) => {
  const [isPressed, setIsPressed] = useState(false);
  const [swipeX, setSwipeX] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);
  const startXRef = useRef(0);
  const currentXRef = useRef(0);

  const category = getCategoryFromName(property.name);
  const categoryIcon = getCategoryIcon(property.name);
  const needsVerification = !property.verified;
  const lastInventoryDate = property.lastInventoryDate;

  // Swipe threshold for triggering actions
  const SWIPE_THRESHOLD = 80;
  const MAX_SWIPE = 200;

  const handleTouchStart = (e: React.TouchEvent) => {
    if (isSelectMode) return;
    startXRef.current = e.touches[0].clientX;
    currentXRef.current = e.touches[0].clientX;
    setIsDragging(true);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!isDragging || isSelectMode) return;
    
    currentXRef.current = e.touches[0].clientX;
    const deltaX = currentXRef.current - startXRef.current;
    
    // Apply resistance at edges
    let newSwipeX = deltaX;
    if (Math.abs(deltaX) > SWIPE_THRESHOLD) {
      const excess = Math.abs(deltaX) - SWIPE_THRESHOLD;
      const resistance = 1 - (excess / (MAX_SWIPE - SWIPE_THRESHOLD)) * 0.5;
      newSwipeX = Math.sign(deltaX) * (SWIPE_THRESHOLD + excess * resistance);
    }
    
    // Clamp to max swipe distance
    newSwipeX = Math.max(-MAX_SWIPE, Math.min(MAX_SWIPE, newSwipeX));
    setSwipeX(newSwipeX);
  };

  const handleTouchEnd = () => {
    if (!isDragging || isSelectMode) return;
    
    const deltaX = currentXRef.current - startXRef.current;
    
    // Trigger actions based on swipe direction and distance
    if (deltaX < -SWIPE_THRESHOLD) {
      // Swiped left - show transfer action
      onTransfer();
    }
    
    // Reset position
    setSwipeX(0);
    setIsDragging(false);
  };

  const getStatusConfig = (status: string) => {
    const normalizedStatus = normalizeItemStatus(status);
    switch (normalizedStatus) {
      case 'Operational': 
        return { 
          color: 'text-green-500', 
          bgColor: 'bg-green-500/10', 
          icon: CheckCircle,
          label: 'FMC'
        };
      case 'Maintenance': 
        return { 
          color: 'text-orange-500', 
          bgColor: 'bg-orange-500/10', 
          icon: Wrench,
          label: 'DL'
        };
      case 'Non-Operational': 
        return { 
          color: 'text-red-500', 
          bgColor: 'bg-red-500/10', 
          icon: AlertTriangle,
          label: 'NMC'
        };
      case 'Missing': 
        return { 
          color: 'text-red-600', 
          bgColor: 'bg-red-600/10', 
          icon: AlertTriangle,
          label: 'MISSING'
        };
      default: 
        return { 
          color: 'text-ios-secondary-text', 
          bgColor: 'bg-ios-tertiary-background', 
          icon: Info,
          label: status || 'UNKNOWN'
        };
    }
  };

  const getVerificationStatus = (date: string | null) => {
    if (!date) return { status: 'never', label: 'Never verified', color: 'text-ios-destructive' };
    const daysSince = Math.floor((Date.now() - new Date(date).getTime()) / (1000 * 60 * 60 * 24));
    if (daysSince > 90) return { status: 'overdue', label: `${daysSince} days ago`, color: 'text-ios-destructive' };
    if (daysSince > 30) return { status: 'due', label: `${daysSince} days ago`, color: 'text-ios-warning' };
    if (daysSince === 0) return { status: 'recent', label: 'Today', color: 'text-green-500' };
    if (daysSince === 1) return { status: 'recent', label: 'Yesterday', color: 'text-green-500' };
    return { status: 'ok', label: `${daysSince} days ago`, color: 'text-ios-secondary-text' };
  };

  return (
    <div className="relative">
      {/* Background action indicators */}
      <div className="absolute inset-0 flex items-center justify-end px-6 overflow-hidden rounded-xl">
        <div className={cn(
          "flex items-center gap-2 transition-opacity",
          swipeX < -SWIPE_THRESHOLD / 2 ? "opacity-100" : "opacity-0"
        )}>
          <span className="text-sm font-medium text-ios-accent">Transfer</span>
          <ArrowLeftRight className="h-5 w-5 text-ios-accent" />
        </div>
      </div>

      {/* Swipeable card */}
      <div
        ref={cardRef}
        className={cn(
          "relative transition-transform",
          isDragging ? "" : "duration-200",
          isPressed && !isDragging ? "scale-[0.98]" : "scale-100"
        )}
        style={{
          transform: `translateX(${swipeX}px)`,
        }}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        onMouseDown={() => setIsPressed(true)}
        onMouseUp={() => setIsPressed(false)}
        onMouseLeave={() => setIsPressed(false)}
      >
        <CleanCard 
          className={cn(
            "cursor-pointer bg-gradient-to-br from-white to-gray-50 shadow-md hover:shadow-xl transition-all duration-300 overflow-hidden border border-gray-200/50 hover:border-ios-accent/30 hover:scale-[1.02] transform-gpu",
            isSelected && "ring-2 ring-ios-accent border-ios-accent shadow-lg scale-[1.02]"
          )}
          onClick={onTap}
          padding="none"
        >
          <div className="p-5">
            <div className="space-y-4">
              {/* Property header with enhanced design */}
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-start gap-3">
                    {/* Selection checkbox or category icon */}
                    {isSelectMode ? (
                      <div className={cn(
                        "w-5 h-5 rounded-md border-2 flex items-center justify-center transition-all duration-200 flex-shrink-0 mt-0.5",
                        isSelected ? "bg-ios-accent border-ios-accent scale-110" : "border-ios-border hover:border-ios-accent/50"
                      )}>
                        {isSelected && (
                          <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    ) : (
                      <div className={cn(
                        "p-2.5 rounded-lg flex-shrink-0",
                        category !== 'other' ? getCategoryColor(property.name).replace('text-', 'bg-').replace('500', '500/10') : 'bg-ios-tertiary-background'
                      )}>
                        {category !== 'other' ? (
                          <span className={cn("text-xl", getCategoryColor(property.name))}>
                            {categoryIcon}
                          </span>
                        ) : (
                          <Package className="h-5 w-5 text-ios-secondary-text" />
                        )}
                      </div>
                    )}
                    
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="text-base font-semibold text-ios-primary-text truncate">
                          {property.name}
                        </h3>
                        {property.isSensitive && (
                          <div className="p-1 bg-orange-500/10 rounded">
                            <Shield className="h-3.5 w-3.5 text-orange-500" />
                          </div>
                        )}
                      </div>
                      
                      <div className="space-y-1">
                        <div className="flex items-center gap-3 text-xs">
                          <span className="flex items-center gap-1 text-ios-secondary-text">
                            <FileText className="h-3 w-3" />
                            <span className="font-['Courier_New',_monospace]">SN: {property.serialNumber}</span>
                          </span>
                          {property.nsn && (
                            <span className="flex items-center gap-1 text-ios-tertiary-text">
                              <Package className="h-3 w-3" />
                              <span className="font-['Courier_New',_monospace]">NSN: {property.nsn}</span>
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                
                {/* Status badge */}
                <div className="flex-shrink-0">
                  {(() => {
                    const statusConfig = getStatusConfig(property.status || 'Unknown');
                    const StatusIcon = statusConfig.icon;
                    return (
                      <div className={cn(
                        "px-3 py-1.5 rounded-full flex items-center gap-1.5",
                        statusConfig.bgColor
                      )}>
                        <StatusIcon className={cn("h-3.5 w-3.5", statusConfig.color)} />
                        <span className={cn(
                          "text-xs font-semibold uppercase tracking-wider",
                          statusConfig.color
                        )}>
                          {statusConfig.label}
                        </span>
                      </div>
                    );
                  })()}
                </div>
              </div>
              
              {/* Additional info and actions */}
              <div className="flex items-center justify-between pt-2 border-t border-ios-divider">
                <div className="flex items-center gap-4">
                  {/* Verification status */}
                  {lastInventoryDate && (() => {
                    const verificationStatus = getVerificationStatus(lastInventoryDate);
                    return (
                      <div className="flex items-center gap-1.5">
                        <Calendar className={cn("h-3.5 w-3.5", verificationStatus.color)} />
                        <span className={cn("text-xs", verificationStatus.color)}>
                          Verified {verificationStatus.label}
                        </span>
                      </div>
                    );
                  })()}
                  
                  {/* Component count if any */}
                  {property.components && property.components.length > 0 && (
                    <div className="flex items-center gap-1.5 text-ios-secondary-text">
                      <Package className="h-3.5 w-3.5" />
                      <span className="text-xs">
                        {property.components.length} components
                      </span>
                    </div>
                  )}
                </div>
                
                {/* Action indicator */}
                {!isSelectMode && (
                  <div className="flex items-center gap-2">
                    <ChevronRight className="h-4 w-4 text-ios-tertiary-text" />
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* Quick action bar for desktop */}
          {!isSelectMode && (
            <div className="hidden md:flex items-center justify-between px-5 py-3 bg-ios-tertiary-background/50 border-t border-ios-divider">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onViewDetails?.();
                }}
                className="text-xs font-medium text-ios-secondary-text hover:text-ios-primary-text transition-colors flex items-center gap-1.5"
              >
                <Eye className="h-3.5 w-3.5" />
                View Details
              </button>
              
              <div className="flex items-center gap-3">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onTransfer();
                  }}
                  className="text-xs font-medium text-ios-accent hover:text-ios-accent/80 transition-colors flex items-center gap-1.5"
                >
                  <ArrowLeftRight className="h-3.5 w-3.5" />
                  Transfer
                </button>
              </div>
            </div>
          )}
        </CleanCard>
      </div>
    </div>
  );
};