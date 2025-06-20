import React, { useRef, useState, useEffect } from 'react';
import { cn } from '@/lib/utils';

interface ScrollableContainerProps {
  children: React.ReactNode;
  className?: string;
  fadeEdges?: boolean;
}

export const ScrollableContainer: React.FC<ScrollableContainerProps> = ({ 
  children, 
  className,
  fadeEdges = true 
}) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [showLeftFade, setShowLeftFade] = useState(false);
  const [showRightFade, setShowRightFade] = useState(false);

  const checkScroll = () => {
    if (scrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current;
      setShowLeftFade(scrollLeft > 0);
      setShowRightFade(scrollLeft < scrollWidth - clientWidth - 1);
    }
  };

  useEffect(() => {
    checkScroll();
    window.addEventListener('resize', checkScroll);
    return () => window.removeEventListener('resize', checkScroll);
  }, []);

  return (
    <div className="relative">
      {fadeEdges && showLeftFade && (
        <div className="absolute left-0 top-0 bottom-0 w-8 bg-gradient-to-r from-white to-transparent z-10 pointer-events-none" />
      )}
      {fadeEdges && showRightFade && (
        <div className="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-white to-transparent z-10 pointer-events-none" />
      )}
      <div
        ref={scrollRef}
        className={cn("overflow-x-auto scrollbar-hide", className)}
        onScroll={checkScroll}
        style={{ 
          WebkitOverflowScrolling: 'touch',
          overscrollBehavior: 'contain'
        }}
      >
        {children}
      </div>
    </div>
  );
};