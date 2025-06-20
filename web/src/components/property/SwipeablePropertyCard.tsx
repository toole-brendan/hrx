import React, { useState, useRef, useEffect } from 'react';
import { Property } from '@/types';
import { cn } from '@/lib/utils';
import { getCategoryFromName, getCategoryIcon, getCategoryColor, normalizeItemStatus } from '@/lib/propertyUtils';
import { CleanCard } from '@/components/ios';
import { Shield, Info, ArrowLeftRight, Wrench, Eye } from 'lucide-react';

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
    } else if (deltaX > SWIPE_THRESHOLD && onMaintenance) {
      // Swiped right - show maintenance action
      onMaintenance();
    }
    
    // Reset position
    setSwipeX(0);
    setIsDragging(false);
  };

  const getStatusColor = (status: string) => {
    const normalizedStatus = normalizeItemStatus(status);
    switch (normalizedStatus) {
      case 'Operational': return 'text-ios-success';
      case 'Maintenance': 
      case 'Non-Operational': return 'text-ios-warning';
      case 'Missing': return 'text-ios-destructive';
      default: return 'text-secondary-text';
    }
  };

  const getVerificationDateColor = (date: string | null) => {
    if (!date) return 'text-tertiary-text';
    const daysSince = Math.floor((Date.now() - new Date(date).getTime()) / (1000 * 60 * 60 * 24));
    if (daysSince > 90) return 'text-ios-destructive';
    if (daysSince > 30) return 'text-ios-warning';
    return 'text-secondary-text';
  };

  return (
    <div className="relative overflow-hidden">
      {/* Background action indicators */}
      <div className="absolute inset-0 flex items-center justify-between px-6">
        <div className={cn(
          "flex items-center gap-2 transition-opacity",
          swipeX > SWIPE_THRESHOLD / 2 ? "opacity-100" : "opacity-0"
        )}>
          <Wrench className="h-5 w-5 text-ios-warning" />
          <span className="text-sm font-medium text-ios-warning">Maintenance</span>
        </div>
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
            "cursor-pointer hover:shadow-md transition-shadow duration-200 overflow-hidden bg-white",
            isSelected && "ring-2 ring-ios-accent"
          )}
          onClick={onTap}
          padding="none"
        >
          <div className="p-6">
            <div className="space-y-5">
              {/* Property header */}
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    {isSelectMode && (
                      <div className={cn(
                        "w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors flex-shrink-0",
                        isSelected ? "bg-ios-accent border-ios-accent" : "border-ios-border"
                      )}>
                        {isSelected && (
                          <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    )}
                    <h3 className="text-lg font-medium text-primary-text" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
                      {property.name}
                    </h3>
                    {property.isSensitive && (
                      <Shield className="h-4 w-4 text-ios-warning" />
                    )}
                    {needsVerification && (
                      <Info className="h-4 w-4 text-ios-destructive" />
                    )}
                  </div>
                  <p className="text-sm text-secondary-text font-mono">
                    SN: {property.serialNumber}
                  </p>
                  {property.nsn && (
                    <p className="text-xs text-tertiary-text font-mono mt-1">
                      NSN: {property.nsn}
                    </p>
                  )}
                </div>
                
                {/* Category icon */}
                {category !== 'other' && (
                  <span className={cn("text-2xl", getCategoryColor(property.name))}>
                    {categoryIcon}
                  </span>
                )}
              </div>
              
              {/* Status and verification info */}
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <span className={cn("text-xs uppercase tracking-wide font-medium", getStatusColor(property.status || 'Unknown'))}>
                    {property.status || 'Unknown'}
                  </span>
                </div>
                
                {lastInventoryDate && (
                  <div className="text-right">
                    <p className="text-xs text-tertiary-text">Last verified</p>
                    <p className={cn("text-xs font-medium", getVerificationDateColor(lastInventoryDate))}>
                      {new Date(lastInventoryDate).toLocaleDateString()}
                    </p>
                  </div>
                )}
              </div>
              
              {/* Desktop action buttons */}
              {!isSelectMode && (
                <div className="pt-3 border-t border-ios-divider flex justify-end md:flex hidden">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onTransfer();
                    }}
                    className="text-ios-accent hover:bg-transparent px-0 text-sm font-medium"
                  >
                    Transfer
                  </button>
                </div>
              )}
            </div>
          </div>
        </CleanCard>
      </div>
    </div>
  );
};